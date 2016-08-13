#!/bin/bash

# Usage:
# ./s3-autodelete.sh s3://bucket/path/ "7 days"

set -e

# Maximum date (will delete all files older than this date)
maxDate=`date +%s --date="-$2"`

# Loop thru files
aws s3 ls $1 | while read -r line;  do
    # Get file creation date
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`

    if [[ $createDate -lt $maxDate ]]
    then
        # Get file name
        fileName=`echo $line|awk {'print $4'}`
        if [[ $fileName != "" ]]
          then
              echo "* Delete $fileName";
              aws s3 rm $1"$fileName"
        fi
    fi
done;
