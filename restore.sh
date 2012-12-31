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

DUPLICITY="$(which duplicity)"

if [[ -z "$DUPLICITY"  ]]; then
 echo "Duplicity not found."
 exit 2
fi

if [[ -z "$1" ]]; then
	echo "Provide restore path"
	exit 2
fi

if [ -n "$S3FILESYSLOCATION" ]; then
 $DUPLICITY $S3OPTIONS $EXTRADUPLICITYOPTIONS $S3FILESYSLOCATION $1
fi
