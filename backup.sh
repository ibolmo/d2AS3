#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

### Duplicity Setup ###
if [ ! -f $DIR/setup.sh ];
then 
  echo "File setup.sh does not exist."
  exit 1
fi 

source $DIR/setup.sh

### Env Vars ###
PASSPHRASE_OLD="$(echo $PASSPHRASE)"
AWS_ACCESS_KEY_ID_OLD="$(echo $AWS_ACCESS_KEY_ID)"
AWS_SECRET_ACCESS_KEY_OLD="$(echo $AWS_SECRET_ACCESS_KEY)"
export PASSPHRASE=$PASSPHRASE
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

### Commands ###
if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 mkdir $DIR/mysql/
 MYSQLTMPDIR="$DIR/mysql/"
 MYSQL="$(which mysql)"
 MYSQLDUMP="$(which mysqldump)"
 GZIP="$(which gzip)"
fi
DUPLICITY="$(which duplicity)"

if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
 if [[ -z "$MYSQL" || -z "$MYSQLDUMP" || -z "$GZIP" ]]; then
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
if [[ -n "$BACKUPFILES" && "$BACKUPFILES" -gt 0 ]]; then
  if [ -n "$S3FILESYSLOCATION" ]; then
   $DUPLICITY --full-if-older-than $FULLDAYS $S3OPTIONS $EXTRADUPLICITYOPTIONS --allow-source-mismatch --include-globbing-filelist $INCLUDEFILES --exclude '**' / $S3FILESYSLOCATION
 fi
fi

if [[ -n "$BACKUPMYSQL" && "$BACKUPMYSQL" -gt 0 ]]; then
  if [ -n "$S3MYSQLLOCATION" ]; then
    $DUPLICITY --full-if-older-than $FULLDAYS $S3OPTIONS $EXTRADUPLICITYOPTIONS --allow-source-mismatch $MYSQLTMPDIR $S3MYSQLLOCATION
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
