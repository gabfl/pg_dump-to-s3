#!/usr/bin/env bats

load test_helper

setup() {
    common_setup
    export STUB_PSQL_STDIN="$BATS_TEST_TMPDIR/psql_stdin.sql"
}

@test "prints usage and exits 0 without arguments" {
    run "$ROOT/pg_restore-from-s3.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE:"* ]]
    [ ! -s "$STUB_LOG" ]
}

@test "prints usage and fails with a single argument" {
    run "$ROOT/pg_restore-from-s3.sh" mydb
    [ "$status" -ne 0 ]
    [[ "$output" == *"USAGE:"* ]]
    [ ! -s "$STUB_LOG" ]
}

@test "restores with --clean into an existing database" {
    export STUB_DB_EXISTS=1
    run "$ROOT/pg_restore-from-s3.sh" mydb 2023-06-28_mydb.dump
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
    [[ "$output" == *"2023-06-28_mydb.dump restored to database mydb"* ]]

    grep -q '^aws \[s3\] \[cp\] \[s3://bucket/backups/2023-06-28_mydb.dump\]' "$STUB_LOG"
    grep -q '^pg_restore .* \[-d\] \[mydb\] \[-Fc\] \[--clean\]' "$STUB_LOG"
    ! grep -q '^createdb' "$STUB_LOG"
}

@test "creates the database when it does not exist" {
    run "$ROOT/pg_restore-from-s3.sh" newdb backup.dump
    [ "$status" -eq 0 ]
    [[ "$output" == *"Creating database newdb"* ]]

    grep -q '^createdb .* \[-T\] \[template0\] \[newdb\]$' "$STUB_LOG"
    grep -q '^pg_restore .* \[-d\] \[newdb\] \[-Fc\] \[' "$STUB_LOG"
    ! grep -q '\[--clean\]' "$STUB_LOG"
}

@test "passes the database name to psql as a variable, not inline SQL" {
    run "$ROOT/pg_restore-from-s3.sh" "evil'; DROP TABLE x; --" backup.dump
    [ "$status" -eq 0 ]
    grep -q "^psql .* \[-v\] \[dbname=evil'; DROP TABLE x; --\]" "$STUB_LOG"
    grep -q "datname = :'dbname'" "$STUB_PSQL_STDIN"
    ! grep -q "DROP" "$STUB_PSQL_STDIN"
}

@test "fails when the download fails" {
    export STUB_FAIL=aws
    run "$ROOT/pg_restore-from-s3.sh" mydb backup.dump
    [ "$status" -ne 0 ]
    ! grep -q '^pg_restore' "$STUB_LOG"
}
