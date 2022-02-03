#!/bin/bash
set -x
DATE="$(date +"%Y-%m-%d")"
FILENAME="$DB_NAME-$DATE"
BACKUP_DIR="/new_backup"
#DB_NAME="${DB_NAME}"
#BACKUP_STORAGE_URL="s3://test-backups-20211214"
#BACKUP_TYPE=${BACKUP_TYPE}
#PGUSER="${PGUSER}"
#MYSQL_USER="${MYSQL_USER}"
#MYSQL_PWD="${MYSQL_PWD}"
#HOST="${HOST}"
#BACKUP_STORAGE_URL=${BACKUP_STORAGE_URL}
#SLACK_URL="${SLACK_URL}"
#CLUSTER="${CLUSTER}"

mkdir $BACKUP_DIR
chmod 0777 $BACKUP_DIR
cd $BACKUP_DIR

slack_fail() {
   curl -H "Content-type:application/json" \
   -X POST -d \
   '{
      "attachments" : [
        {
          "color" : "#ff2200",
          "fields" : [
            {
               "title" : ":red_circle: '"[!!ERROR!!] Failed to perform restore database"'",
               "value" : "Type: '"*$1*"'",
               "short" : false
            },
            {
               "value" : "From backup: '"*$2*"'",
               "short" : false
            },
          ]
        }
      ]
    }
   ' "$SLACK_URL"
}
slack_done() {
   curl -H "Content-type:application/json" \
   -X POST -d \
   '{
      "attachments" : [
        {
          "color" : "#00ff0c",
          "fields" : [
            {
               "title" : ":tada: Restore completed successfully",
               "value" : "Type: '"*$1*"'",
               "short" : false
            },
            {
               "value" : "From backup: '"*$2*"'",
               "short" : false
            },
          ]
        }
      ]
    }
   ' "$SLACK_URL"
}

aws_s3_cp() {
aws s3 cp "$BACKUP_STORAGE_URL"/`aws s3 ls "$BACKUP_STORAGE_URL"/"$CLUSTER"/"$1"/ --recursive | sort | tail -n 1 | awk '{print $4}'` "$2"
}

postgres_restore() {
gunzip "$FILENAME.dump.gz"
if pg_restore -U "$PGUSER" -h "$HOST" -W -d "$DB_NAME" "$FILENAME.dump"; then
  slack_done "$BACKUP_TYPE" "$FILENAME.dump.gz"
  else
  slack_fail "$BACKUP_TYPE" "$FILENAME.dump.gz"
fi
}
mysql_restore() {
gunzip "$FILENAME.sql.gz"
if mysql --user="$MYSQL_USER" --password="$MYSQL_PWD" --host="$HOST" "$DB_NAME" < "$FILENAME.sql"; then
  slack_done "$BACKUP_TYPE" "$FILENAME.sql.gz"
  else
  slack_fail "$BACKUP_TYPE" "$FILENAME.sql.gz"
fi
}

if [ "$BACKUP_TYPE" = MYSQL ]; then
  aws_s3_cp "MYSQL" "$FILENAME.sql.gz" && mysql_restore
elif [ "$BACKUP_TYPE" = POSTGRES ]; then
  aws_s3_cp "POSTGRES" "$FILENAME.dump.gz" && postgres_restore
fi

clear() {
rm -r "$BACKUP_DIR"
}
clear
