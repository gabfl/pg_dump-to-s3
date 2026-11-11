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

# Directory containing this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the config file. Lookup order:
#   1. $PG_DUMP_TO_S3_CONF (explicit path)
#   2. ~/.pg_dump-to-s3.conf
#   3. .conf next to this script
load_config() {
    local conf
    if [ -n "${PG_DUMP_TO_S3_CONF:-}" ]; then
        conf="$PG_DUMP_TO_S3_CONF"
    elif [ -f "${HOME}/.pg_dump-to-s3.conf" ]; then
        conf="${HOME}/.pg_dump-to-s3.conf"
    else
        conf="${DIR}/.conf"
    fi

    if [ ! -f "$conf" ]; then
        echo "Error: config file not found: $conf" >&2
        return 1
    fi

    # shellcheck source=.conf
    source "$conf"

    # Defaults
    PG_HOST="${PG_HOST:-127.0.0.1}"
    PG_USER="${PG_USER:-postgres}"
    PG_PORT="${PG_PORT:-5432}"
    DELETE_AFTER="${DELETE_AFTER:-7 days}"
    S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-STANDARD_IA}"

    local var
    for var in PG_DATABASES S3_PATH; do
        if [ -z "${!var:-}" ]; then
            echo "Error: $var is not set in $conf" >&2
            return 1
        fi
    done

    # Strip trailing slash from the S3 path
    S3_PATH="${S3_PATH%/}"
}

# Convert a duration such as "7 days", "2 weeks" or "12 hours" to seconds
duration_to_seconds() {
    local amount unit
    read -r amount unit <<< "$1"

    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid duration: '$1'" >&2
        return 1
    fi

    case "$unit" in
        minute|minutes|min|mins) echo $((amount * 60)) ;;
        hour|hours)              echo $((amount * 3600)) ;;
        day|days|"")             echo $((amount * 86400)) ;;
        week|weeks)              echo $((amount * 604800)) ;;
        *)
            echo "Error: unsupported duration unit '$unit' (use minutes, hours, days or weeks)" >&2
            return 1
            ;;
    esac
}

# Epoch timestamp before which backups are deleted.
# GNU date accepts any relative date ("1 month", "36 hours"); otherwise fall back
# to minutes/hours/days/weeks arithmetic (BSD/macOS).
deletion_cutoff() {
    date -d "-$DELETE_AFTER" +%s 2>/dev/null && return 0
    local max_age
    max_age=$(duration_to_seconds "$DELETE_AFTER")
    echo $(( $(date +%s) - max_age ))
}

# Convert a "YYYY-MM-DD HH:MM:SS" local timestamp to epoch seconds (GNU and BSD date)
to_epoch() {
    date -d "$1" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$1" +%s
}

# Dump each database and upload it to S3
backup_databases() {
    local now tmpdir db file
    now=$(date +"%Y-%m-%d-at-%H-%M-%S")
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT

    local dbs
    IFS=',' read -ra dbs <<< "$PG_DATABASES"

    echo " * Backup in progress..."

    for db in "${dbs[@]}"; do
        # Trim surrounding whitespace
        db="${db#"${db%%[![:space:]]*}"}"
        db="${db%"${db##*[![:space:]]}"}"
        [ -z "$db" ] && continue

        file="${now}_${db}.dump"
        echo "   -> backing up $db..."

        pg_dump -Fc -h "$PG_HOST" -U "$PG_USER" -p "$PG_PORT" "$db" > "$tmpdir/$file"
        aws s3 cp "$tmpdir/$file" "s3://$S3_PATH/$file" --storage-class "$S3_STORAGE_CLASS"
        rm -f "$tmpdir/$file"

        echo "      ...database $db has been backed up"
    done
}

# Delete .dump files older than $DELETE_AFTER from S3
delete_old_backups() {
    local cutoff
    cutoff=$(deletion_cutoff)

    echo " * Deleting old backups..."

    local listing d t _size name created
    listing=$(aws s3 ls "s3://$S3_PATH/")

    while read -r d t _size name; do
        # Skip blank lines, "PRE folder/" entries and non-backup files
        [ -z "$d" ] || [ "$d" = "PRE" ] && continue
        [[ "$name" == *.dump ]] || continue

        created=$(to_epoch "$d $t")
        if [ "$created" -lt "$cutoff" ]; then
            echo "   -> Deleting $name"
            aws s3 rm "s3://$S3_PATH/$name"
        fi
    done <<< "$listing"
}

main() {
    load_config
    backup_databases
    delete_old_backups

    echo ""
    echo "...done!"
    echo ""
}

# Run only when executed, not when sourced (allows testing individual functions)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
