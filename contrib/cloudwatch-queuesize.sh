#!/bin/bash
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | awk -F\" '/region/ {print $4}' )
METRICNAME="$(cat /srv/domserver-cfg/djclusterid)-queuesize"

mapfile -t < /srv/domserver-cfg/dbconfig
RDS_DB_NAME=${MAPFILE[0]}
RDS_HOSTNAME=${MAPFILE[1]}
RDS_USERNAME=${MAPFILE[2]}
RDS_PASSWORD=${MAPFILE[3]}
MYSQL_OPTS="-u $RDS_USERNAME -p$RDS_PASSWORD -h $RDS_HOSTNAME $RDS_DB_NAME"

# Number of submissions with no valid judgings(i.e. in the queue to be judged)
QSIZE=$(mysql $MYSQL_OPTS -s -N -e "SELECT count(s.submitid) from submission s where not exists (select * from judging where submitid = s.submitid and valid = 1)")

aws cloudwatch put-metric-data --namespace "DOMjudge" --metric-name $METRICNAME --value $QSIZE --region $REGION --unit "Count"
