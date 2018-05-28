#!/bin/bash

#                     _                             _                  _____ 
#  _ __   __ _     __| |_   _ _ __ ___  _ __       | |_ ___        ___|___ / 
# | '_ \ / _` |   / _` | | | | '_ ` _ \| '_ \ _____| __/ _ \ _____/ __| |_ \ 
# | |_) | (_| |  | (_| | |_| | | | | | | |_) |_____| || (_) |_____\__ \___) |
# | .__/ \__, |___\__,_|\__,_|_| |_| |_| .__/       \__\___/      |___/____/ 
# |_|    |___/_____|                   |_|                                   
#
# Project at https://github.com/gabfl/pg_dump-to-s3
#

set -e

# Import config file
source $DIR/pg_dump-to-s3.conf

# Vars
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NOW=$(date +"%Y-%m-%d-at-%H-%M-%S")
maxDate=`[ "$(uname)" = Linux ] && date +%s --date="-$DELETE_AFTER"` # Maximum date (will delete all files older than this date)

# Split databases
IFS=',' read -ra DBS <<< "$PG_DATABASES"

# Delere old files
echo " * Backup in progress..";

# Loop thru databases
for db in "${DBS[@]}"; do
    FILENAME="$PREFIX"_"$NOW"_"$db"    

    # Dump database
    pg_dump -Fc -h $PG_HOST -U $PG_USER -p $PG_PORT $db > /tmp/"$FILENAME".dump

    # Copy to S3
    aws s3 cp /tmp/"$FILENAME".dump s3://$S3_PATH/"$FILENAME".dump --storage-class STANDARD_IA

    # Delete local file
    rm /tmp/"$FILENAME".dump

    # Log
    echo " -> database $db has been backed up"
done

# Delere old files
echo " * Deleting old backups...";

# Loop thru files
aws s3 ls s3://$1/ | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $maxDate ]]
    then
    # Get file name
        fileName=`echo $line|awk {'print $4'}`
        if [[ $fileName != "" ]]
          then
            echo " -> Deleting $fileName"
            aws s3 rm s3://$1/$fileName
        fi
    fi
done;

echo ""
echo "...done!";
echo ""
