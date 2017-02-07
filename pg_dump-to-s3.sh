#!/bin/bash

set -e

# Vars
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NOW=$(date +"%m-%d-%Y-at-%H-%M-%S")

source $DIR/secrets.conf

# get databases list
dbs=("$@")

for db in "${dbs[@]}"; do
    FILENAME="$PREFIX"_"$NOW"_"$db"    

    # Dump database
    pg_dump --dbname=$PG_DB > /tmp/"$FILENAME".dump

    # Copy to S3
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY aws s3 cp /tmp/"$FILENAME".dump s3://$S3_PATH/"$FILENAME".dump --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$FILENAME".dump

    # Log
    echo "Database $db is archived"
done

# Delere old files
echo "Delete old backups";
$DIR/s3-autodelete.sh $S3_PATH "$MAX_DAYS days"

