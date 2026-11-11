#!/usr/bin/env bash

#                     _                             _                  _____
#  _ __   __ _     __| |_   _ _ __ ___  _ __       | |_ ___        ___|___ /
# | '_ \ / _` |   / _` | | | | '_ ` _ \| '_ \ _____| __/ _ \ _____/ __| |_ \
# | |_) | (_| |  | (_| | |_| | | | | | | |_) |_____| || (_) |_____\__ \___) |
# | .__/ \__, |___\__,_|\__,_|_| |_| |_| .__/       \__\___/      |___/____/
# |_|    |___/_____|                   |_|
#
# Project at https://github.com/gabfl/pg_dump-to-s3
#

set -euo pipefail

# Reuse config loading from the backup script (sourcing it does not run a backup)
# shellcheck source=pg_dump-to-s3.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pg_dump-to-s3.sh"

usage() {
    cat <<EOF
USAGE:
  $(basename "$0") [db target] [s3 object]

EXAMPLE
  $(basename "$0") service 2023-06-28-at-10-29-44_service.dump
EOF
}

# Returns success if the database exists
database_exists() {
    local result
    # Use a psql variable so the database name is safely quoted
    result=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d postgres -tA \
        -v dbname="$1" <<< "SELECT 1 FROM pg_database WHERE datname = :'dbname';")
    [ "$result" = "1" ]
}

restore() {
    local db="$1" object="$2" tmpdir file
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT
    file="$tmpdir/$(basename "$object")"

    # Download backup from S3
    aws s3 cp "s3://$S3_PATH/$object" "$file"

    if database_exists "$db"; then
        echo "Database $db already exists, skipping creation"
        pg_restore -h "$PG_HOST" -U "$PG_USER" -p "$PG_PORT" -d "$db" -Fc --clean "$file"
    else
        echo "Creating database $db"
        createdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -T template0 "$db"
        pg_restore -h "$PG_HOST" -U "$PG_USER" -p "$PG_PORT" -d "$db" -Fc "$file"
    fi

    echo "$object restored to database $db"
}

restore_main() {
    if [ "$#" -ne 2 ]; then
        usage
        [ "$#" -eq 0 ] && return 0
        return 1
    fi

    load_config
    restore "$1" "$2"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    restore_main "$@"
fi
