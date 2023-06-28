#!/bin/bash

set -e

# Set current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Import config file
source $DIR/pg_dump-to-s3.conf

# Usage
__usage="
USAGE:
  $(basename $0) [db target] [s3 object]

EXAMPLE
  $(basename $0) service 2023-06-28-at-10-29-44_service.dump
"

if [[ -z "$@" ]]; then
    echo "$__usage"
    exit 0
fi

# Download backup from s3
aws s3 cp s3://$S3_PATH/$2 /tmp/$2

# Create database if not exists
DB_EXISTS=$(psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$1'")
if [ "$DB_EXISTS" = "1" ]
then
    echo "Database $1 already exists, skipping creation"
    # Restore database
    pg_restore -h $PG_HOST -U $PG_USER -p $PG_PORT -d $1 -Fc --clean /tmp/$2
else
    echo "Creating database $1"
    createdb -h $PG_HOST -p $PG_PORT -U $PG_USER -T template0 $1
    # Restore database
    pg_restore -h $PG_HOST -U $PG_USER -p $PG_PORT -d $1 -Fc /tmp/$2
fi

# Remove backup file
rm /tmp/$2

echo "$2 restored to database $1"
