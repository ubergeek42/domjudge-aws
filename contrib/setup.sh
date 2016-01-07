#!/bin/bash

DEPLOYPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
APACHECONF="${DEPLOYPATH}/apache2.conf"

# Environment variables are assumed to exist(they come from the userdata on deployment)
#/srv/domserver-cfg/djclusterid  # generic identifier
#/srv/domserver-cfg/dbconfig     # for rds database
#/srv/domserver-cfg/sessiontable # for dynamodb
mkdir -p /srv/domserver-cfg
cat >/srv/domserver-cfg/djclusterid <<EOF
$DJCLUSTERID
EOF

cat >/srv/domserver-cfg/dbconfig <<EOF
${DBNAME}
${DBHOST}
${DBUSER}
${DBPASS}
EOF

cat >/srv/domserver-cfg/dynamodb <<EOF
${DYNAMODB_TABLE}
${DYNAMODB_REGION}
EOF

# Initialize database
function initDB() {
  mapfile -t < /srv/domserver-cfg/dbconfig
  RDS_DB_NAME=${MAPFILE[0]}
  RDS_HOSTNAME=${MAPFILE[1]}
  RDS_USERNAME=${MAPFILE[2]}
  RDS_PASSWORD=${MAPFILE[3]}

  MYSQL_OPTS="-u $RDS_USERNAME -p$RDS_PASSWORD -h $RDS_HOSTNAME $RDS_DB_NAME"

  if mysql $MYSQL_OPTS -e "SELECT username FROM user WHERE username = 'admin';"; then
    echo "Database already configured, doing nothing"
    return
  fi

  echo "Initializing database..."
  SQLDIR="$DEPLOYPATH/domserver/sql"
  FILES="$SQLDIR/mysql_db_structure.sql \
    $SQLDIR/mysql_db_defaultdata.sql \
    $SQLDIR/mysql_db_files_defaultdata.sql"
  cat $FILES | mysql $MYSQL_OPTS
  echo "Database initialized"

  return
}


function createApacheConf() {
  cat > $APACHECONF <<EOF
# Apache configuration for DOMjudge
<IfModule mod_remoteip.c>
  RemoteIPHeader X-Forwarded-For
</IfModule>
<VirtualHost *:80>
  DocumentRoot ${DEPLOYPATH}/domserver/www
  RedirectMatch ^/api$ /api/
  Alias /api ${DEPLOYPATH}/domserver/www/api/index.php

  LogFormat "%a %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" elb_combined
  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log elb_combined

  <IfModule mod_php5.c>
    php_value memory_limit          256M
    php_value upload_max_filesize   256M
    php_value post_max_size         256M
    php_value max_file_uploads      100
    php_value date.timezone         "America/New_York"

    php_flag magic_quotes_gpc off
    php_flag magic_quotes_runtime off
  </IfModule>
</VirtualHost>

<Directory ${DEPLOYPATH}/domserver/www>
  <IfModule !mod_authz_core.c>
    # For Apache 2.2:
    Order allow,deny
    Allow from all
  </IfModule>
  <IfModule mod_authz_core.c>
    # For Apache 2.4:
    Require all granted
  </IfModule>

  Options FollowSymlinks
  DirectoryIndex index.php
  AllowOverride None
</Directory>
<Directory ${DEPLOYPATH}/domserver/www/doc>
  Options +Indexes
</Directory>
EOF
}

initDB
createApacheConf

# Make sure apache has the remoteip module enabled
/usr/sbin/a2enmod remoteip

# Make sure the webserver has access to certain folders
chown www-data:www-data ${DEPLOYPATH}/domserver/{run,submissions,log,tmp}

# Set up a cron task for useful things
cat > /etc/cron.d/domserver <<EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
* * * * *  root /bin/bash ${DEPLOYPATH}/cloudwatch-queuesize.sh
EOF
chown root:root /etc/cron.d/domserver
chmod 644 /etc/cron.d/domserver
