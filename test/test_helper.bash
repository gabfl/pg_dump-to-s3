# Shared setup for the bats test suite

ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

common_setup() {
    export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
    : > "$STUB_LOG"
    export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"

    # Isolate from any real config in the user's home directory
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"

    export PG_DUMP_TO_S3_CONF="$BATS_TEST_TMPDIR/test.conf"
    write_conf
}

# Write a config file; extra lines passed as arguments are appended
write_conf() {
    cat > "$PG_DUMP_TO_S3_CONF" <<EOF
PG_HOST="db.example"
PG_USER="backup"
PG_PORT=5433
PG_DATABASES="alpha, beta"
S3_PATH="bucket/backups/"
DELETE_AFTER="7 days"
EOF
    local line
    for line in "$@"; do
        echo "$line" >> "$PG_DUMP_TO_S3_CONF"
    done
}

# Format an epoch timestamp the way `aws s3 ls` prints it
s3_date() {
    date -d "@$1" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$1" +"%Y-%m-%d %H:%M:%S"
}
