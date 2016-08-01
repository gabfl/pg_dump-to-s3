#!/bin/bash

set -e

# Database credentials
PG_HOST="localhost"
PG_USER="my_user"

# S3
S3_PATH="bucket/folder/sub_folder"

# get databases list
dbs=("$@")

# Vars
NOW=$(date +"%m-%d-%Y-at-%H-%M-%S")
EXPIRATION_DATE=`date --date="1 week" +%Y-%m-%d`

for db in "${dbs[@]}"; do
    # Dump database
    pg_dump -Fc -h $PG_HOST -U $PG_USER $db > /tmp/"$NOW"_"$db".dump

    # Copy to S3
    aws s3 cp /tmp/"$NOW"_"$db".dump s3://$S3_PATH/"$NOW"_"$db".dump --expires $EXPIRATION_DATE --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$NOW"_"$db".dump

    # Log
    echo "* Database $db is archived"
done
