#!/bin/bash
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BUILD_OUTPUT="$BASEDIR/output"
CONTRIB_DIR="$BASEDIR/contrib"
VENDOR_DIR="$BASEDIR/vendor"

DOMJUDGE_SRC="$BASEDIR/build/domjudge-src"
DOMSERVER_INSTALL_DIR="$BUILD_OUTPUT/domserver"

ARCHIVE="domserver-$(date +%Y-%m-%d-%H%M%S).tar.gz"

# Edit these variables to your liking! You should set S3 Bucket
# to the name of the bucket you want to use for your domserver install archives
DOMJUDGE_REPO="https://github.com/domjudge/domjudge.git"
#DOMJUDGE_REPO="https://github.com/ubergeek42/domjudge.git"
TAGNAME="5.0"
S3BUCKET="domserver-archives"

function copy_contrib() {
  cp $CONTRIB_DIR/{setup.sh,cloudwatch-queuesize.sh} $BUILD_OUTPUT
  cp -r $VENDOR_DIR/aws_php_sdk $BUILD_OUTPUT
}

function create_archive() {
  echo "Building archive"
  tar -czf $ARCHIVE -C $BUILD_OUTPUT .
}

function upload_s3() {
  aws s3 mb s3://$S3BUCKET
  aws s3 cp $ARCHIVE s3://$S3BUCKET/$ARCHIVE
}

# Builds and installs the DOMserver
function build_domjudge() {
  if [ ! -d $DOMJUDGE_SRC ]; then
    git clone $DOMJUDGE_REPO $DOMJUDGE_SRC
  else
    (cd $DOMJUDGE_SRC; git pull)
  fi

  if [ -d $DOMSERVER_INSTALL_DIR ]; then
    echo "DOMserver already installed, deleting"
    rm -rf $DOMSERVER_INSTALL_DIR
  fi

  cd $DOMJUDGE_SRC
  git checkout $TAGNAME

  # Prepare for running configure
  make distclean
  aclocal -I m4
  autoheader
  autoconf

  # Do the configure and install
  ./configure --disable-submitclient --prefix=$DOMSERVER_INSTALL_DIR --with-domserver_root=$DOMSERVER_INSTALL_DIR
  make domserver docs
  make install-domserver
  cd $BASEDIR

  # do some post install setup

  # Copy docs manually
  mkdir -p $DOMSERVER_INSTALL_DIR/www/doc/{admin,team,judge,examples}
  cp $DOMJUDGE_SRC/doc/admin/{*.html,*.pdf} $DOMSERVER_INSTALL_DIR/www/doc/admin/
  cp $DOMJUDGE_SRC/doc/team/{*.html,*.pdf} $DOMSERVER_INSTALL_DIR/www/doc/team/
  cp $DOMJUDGE_SRC/doc/judge/{*.html,*.pdf} $DOMSERVER_INSTALL_DIR/www/doc/judge/
  cp $DOMJUDGE_SRC/doc/examples/{example.*,*.in,*.out,*.pdf} $DOMSERVER_INSTALL_DIR/www/doc/examples/

  # copy in our customizations for using Amazon RDS
  cp $CONTRIB_DIR/use_db.php $DOMSERVER_INSTALL_DIR/lib/use_db.php

  # update lib/lib.auth.php to talk to dynamodb for sessions
  cat $CONTRIB_DIR/dynamodb_snippet.php $DOMSERVER_INSTALL_DIR/lib/www/auth.php > $DOMSERVER_INSTALL_DIR/lib/www/auth.dynamodbsession.php
  mv $DOMSERVER_INSTALL_DIR/lib/www/auth.dynamodbsession.php $DOMSERVER_INSTALL_DIR/lib/www/auth.php

  # copy in a nice simple AWS metrics page(And add a link to it)
  cp $CONTRIB_DIR/cwmetrics/metrics.php $DOMSERVER_INSTALL_DIR/www/jury/
  cp $CONTRIB_DIR/cwmetrics/jquery.flot.byte.js $DOMSERVER_INSTALL_DIR/www/js/flot
  cp $CONTRIB_DIR/cwmetrics/jquery.flot.tooltip.js $DOMSERVER_INSTALL_DIR/www/js/flot
  sed -i '/^<li><a href="auditlog.php">Activity log/a<li><a href="metrics.php">Server Metrics</a></li>' $DOMSERVER_INSTALL_DIR/www/jury/index.php

  # Copy affiliations and country images
  rm -rf $DOMSERVER_INSTALL_DIR/www/images/{affiliations,countries}
  cp -r $CONTRIB_DIR/images/{affiliations,countries} $DOMSERVER_INSTALL_DIR/www/images/


  # perform path replacements in various places
  echo "Fixing paths"
  sed -i "s|'$DOMSERVER_INSTALL_DIR/|__DIR__ .'/../|g" $DOMSERVER_INSTALL_DIR/www/configure.php
  sed -i "s|'$DOMSERVER_INSTALL_DIR/|__DIR__ .'/../|g" $DOMSERVER_INSTALL_DIR/etc/domserver-static.php
  sed -i "s|\"$DOMSERVER_INSTALL_DIR/|__DIR__ .\"/../|g" $DOMSERVER_INSTALL_DIR/bin/balloons


  # Delete files we don't need
  rm $DOMSERVER_INSTALL_DIR/etc/dbpasswords.secret
  rm $DOMSERVER_INSTALL_DIR/etc/restapi.secret
  rm $DOMSERVER_INSTALL_DIR/etc/gendbpasswords
  rm $DOMSERVER_INSTALL_DIR/etc/genrestapicredentials

  rm $DOMSERVER_INSTALL_DIR/bin/create_accounts
  rm $DOMSERVER_INSTALL_DIR/www/jury/doc
  rm $DOMSERVER_INSTALL_DIR/etc/apache.conf
  rm $DOMSERVER_INSTALL_DIR/etc/nginx-conf
  rm $DOMSERVER_INSTALL_DIR/bin/dj-setup-database
}

build_domjudge
copy_contrib
create_archive
upload_s3

echo "DOMserver \"$TAGNAME\" Built"
echo "Uploaded to S3"
