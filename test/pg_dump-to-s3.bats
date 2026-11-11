#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
}

@test "backs up every database and uploads it to S3" {
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"database alpha has been backed up"* ]]
    [[ "$output" == *"database beta has been backed up"* ]]
    [[ "$output" == *"...done!"* ]]

    grep -q '^pg_dump \[-Fc\] \[-h\] \[db.example\] \[-U\] \[backup\] \[-p\] \[5433\] \[alpha\]$' "$STUB_LOG"
    grep -q '^pg_dump .* \[beta\]$' "$STUB_LOG"

    # Trailing slash in S3_PATH is stripped and storage class defaults to STANDARD_IA
    grep -Eq '^aws \[s3\] \[cp\] \[.*_alpha\.dump\] \[s3://bucket/backups/[0-9-]+-at-[0-9-]+_alpha\.dump\] \[--storage-class\] \[STANDARD_IA\]$' "$STUB_LOG"
    grep -Eq '^aws \[s3\] \[cp\] .*_beta\.dump\]' "$STUB_LOG"
}

@test "honors a custom storage class" {
    write_conf 'S3_STORAGE_CLASS="GLACIER_IR"'
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -eq 0 ]
    grep -q '\[--storage-class\] \[GLACIER_IR\]' "$STUB_LOG"
}

@test "stops and does not upload when pg_dump fails" {
    export STUB_FAIL=pg_dump
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -ne 0 ]
    ! grep -q '^aws \[s3\] \[cp\]' "$STUB_LOG"
}

@test "stops when the upload fails" {
    export STUB_FAIL=aws
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -ne 0 ]
    [[ "$output" != *"database alpha has been backed up"* ]]
}

@test "deletes only .dump files older than DELETE_AFTER" {
    local now old recent
    now=$(date +%s)
    old=$(s3_date $((now - 10 * 86400)))
    recent=$(s3_date $((now - 1 * 86400)))

    export STUB_S3_LS="$BATS_TEST_TMPDIR/ls.txt"
    cat > "$STUB_S3_LS" <<EOF
                           PRE subfolder/
$old       1024 old_alpha.dump
$recent       2048 recent_alpha.dump
$old         12 notes.txt
EOF

    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleting old_alpha.dump"* ]]

    grep -q '^aws \[s3\] \[rm\] \[s3://bucket/backups/old_alpha.dump\]$' "$STUB_LOG"
    [ "$(grep -c '^aws \[s3\] \[rm\]' "$STUB_LOG")" -eq 1 ]
}

@test "fails when the config file is missing" {
    export PG_DUMP_TO_S3_CONF="$BATS_TEST_TMPDIR/nope.conf"
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"config file not found"* ]]
    [ ! -s "$STUB_LOG" ]
}

@test "fails when a required setting is missing" {
    echo 'PG_DATABASES=""' > "$PG_DUMP_TO_S3_CONF"
    echo 'S3_PATH="bucket"' >> "$PG_DUMP_TO_S3_CONF"
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"PG_DATABASES is not set"* ]]
}

@test "uses ~/.pg_dump-to-s3.conf when no explicit config is given" {
    unset PG_DUMP_TO_S3_CONF
    cat > "$HOME/.pg_dump-to-s3.conf" <<EOF
PG_DATABASES="fromhome"
S3_PATH="homebucket"
EOF
    run "$ROOT/pg_dump-to-s3.sh"
    [ "$status" -eq 0 ]
    grep -q '^pg_dump .* \[fromhome\]$' "$STUB_LOG"
    grep -q 's3://homebucket/' "$STUB_LOG"
}

@test "duration_to_seconds converts supported units" {
    source "$ROOT/pg_dump-to-s3.sh"
    [ "$(duration_to_seconds "7 days")" -eq 604800 ]
    [ "$(duration_to_seconds "1 day")" -eq 86400 ]
    [ "$(duration_to_seconds "2 weeks")" -eq 1209600 ]
    [ "$(duration_to_seconds "12 hours")" -eq 43200 ]
    [ "$(duration_to_seconds "30 minutes")" -eq 1800 ]
    [ "$(duration_to_seconds "3")" -eq 259200 ]
}

@test "duration_to_seconds rejects invalid input" {
    source "$ROOT/pg_dump-to-s3.sh"
    run duration_to_seconds "soon"
    [ "$status" -ne 0 ]
    run duration_to_seconds "3 fortnights"
    [ "$status" -ne 0 ]
}

@test "deletion_cutoff is DELETE_AFTER before now" {
    source "$ROOT/pg_dump-to-s3.sh"
    DELETE_AFTER="7 days"
    local expected actual
    expected=$(( $(date +%s) - 604800 ))
    actual=$(deletion_cutoff)
    # Allow a few seconds of drift
    [ $((actual - expected)) -ge -5 ] && [ $((actual - expected)) -le 5 ]
}
