#!/bin/bash

set -e

source secrets.conf

# get databases list
dbs=("$@")

# Vars
NOW=$(date +"%m-%d-%Y-at-%H-%M-%S")
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for db in "${dbs[@]}"; do
    # Dump database
    pg_dump --dbname=$PG_DB > /tmp/"$NOW"_"$db".dump

    # Copy to S3
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY aws s3 cp /tmp/"$NOW"_"$db".dump s3://$S3_PATH/"$NOW"_"$db".dump --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$NOW"_"$db".dump

    # Log
    echo "* Database $db is archived"
done

# Delere old files
echo "* Delete old backups";
$DIR/s3-autodelete.sh $S3_PATH "$MAX_DAYS days"

