#!/bin/bash

### Duplicity Setup ###
if [ ! -f source.sh ];
then 
  echo "File source.sh does not exist."
  exit 1
fi 

source source.sh

# This needs to be a newline separated list of files and directories to backup
INCLUDEFILES="./includes.txt"

S3FILESYSLOCATION="s3+http://$(hostname)"
S3MYSQLLOCATION="s3+http://$(hostname)"
S3OPTIONS="--s3-use-new-style"

EXTRADUPLICITYOPTIONS="-v8"

FULLDAYS="14D"
MAXFULL=2

### MySQL Setup ###
MUSER="<your mysql user>"
MPASS="<mysql user's password>"
MHOST="localhost"

### Disable MySQL ###
# Change to 0 to disable
BACKUPMYSQL=0

###### End Of Editable Parts ######

### Env Vars ###
PASSPHRASE_OLD="$(echo $PASSPHRASE)"
AWS_ACCESS_KEY_ID_OLD="$(echo $AWS_ACCESS_KEY_ID)"
AWS_SECRET_ACCESS_KEY_OLD="$(echo $AWS_SECRET_ACCESS_KEY)"
export PASSPHRASE=$PASSPHRASE
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

### Commands ###
if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 MYSQLTMPDIR="$(mktemp -d -t d2AS3)"
 MYSQL="$(which mysql)"
 MYSQLDUMP="$(which mysqldump)"
 GZIP="$(which gzip)"
fi
DUPLICITY="$(which duplicity)"

if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 if [[ -n "$MYSQL" || -n "$MYSQL" || -n "$MYSQLDUMP" || -n "$GZIP" ]]; then
  echo "Not all MySQL commands found."
  exit 2
 fi
fi

if [[ -z "$DUPLICITY"  ]]; then
 echo "Duplicity not found."
 exit 2
fi

### Dump MySQL Databases ###
if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 # Get all databases name
 DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
 for db in $DBS
 do
  if [ "$db" != "information_schema" ]; then
   $MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS $db | $GZIP -9 > $MYSQLTMPDIR/mysql-$db
  fi
 done
fi

### Backup files ###
if [ -n "$S3FILESYSLOCATION" ]; then
 $DUPLICITY --full-if-older-than $FULLDAYS $S3OPTIONS --name=files $EXTRADUPLICITYOPTIONS --include-globbing-filelist $INCLUDEFILES --exclude '**' / $S3FILESYSLOCATION
fi
if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 if [ -n "$S3MYSQLLOCATION" ]; then
  $DUPLICITY --full-if-older-than $FULLDAYS $S3OPTIONS --name=mysql $EXTRADUPLICITYOPTIONS --allow-source-mismatch $MYSQLTMPDIR $S3MYSQLLOCATION
 fi
fi

### Cleanup ###
if [[ -n "$MAXFULL" && "$MAXFULL" -gt 0 ]]; then
 if [ -n "$S3FILESYSLOCATION" ]; then
  $DUPLICITY remove-all-but-n-full $MAXFULL  --name=files $S3FILESYSLOCATION
 fi
 if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
  if [ -n "$S3MYSQLLOCATION" ]; then
   $DUPLICITY remove-all-but-n-full $MAXFULL --name=mysql $S3MYSQLLOCATION
  fi
 fi
fi
if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 rm -rf $MYSQLTMPDIR
fi
export PASSPHRASE=$PASSPHRASE_OLD
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_OLD
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_OLD
