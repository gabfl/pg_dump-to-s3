# pg_dump-to-s3

[![Test](https://github.com/gabfl/pg_dump-to-s3/actions/workflows/test.yml/badge.svg)](https://github.com/gabfl/pg_dump-to-s3/actions/workflows/test.yml)

Automatically dump and archive PostgreSQL backups to Amazon S3.

## Requirements

 - Bash and the PostgreSQL client tools (`pg_dump`, `pg_restore`, `psql`, `createdb`)
 - [AWS CLI](https://aws.amazon.com/cli)

Works on Linux and macOS.

## Setup

 - Use `aws configure` to store your AWS credentials in `~/.aws` ([read documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-quick-configuration))
 - Edit `.conf` and set your PostgreSQL's credentials and the list of databases to back up. The config file is looked up in this order:
   1. the path in the `PG_DUMP_TO_S3_CONF` environment variable
   2. `~/.pg_dump-to-s3.conf`
   3. `.conf` next to the scripts
 - If your PostgreSQL connection uses a password, you will need to store it in `~/.pgpass` ([read documentation](https://www.postgresql.org/docs/current/static/libpq-pgpass.html))

## Usage

```bash
./pg_dump-to-s3.sh

#  * Backup in progress...
#    -> backing up test...
# upload: ../../../tmp/2023-06-28-at-22-20-08_test.dump to s3://*****/backups/2023-06-28-at-22-20-08_test.dump
#       ...database test has been backed up
#  * Deleting old backups...

# ...done!
```

## Restore a backup

```bash
# USAGE: pg_restore-from-s3.sh [db target] [s3 object]

./pg_restore-from-s3.sh my_database_1 2023-06-28-at-10-29-44_my_database_1.dump

# download: s3://your_bucket/folder/2023-06-28-at-22-17-15_my_database_1.dump to /tmp/2023-06-28-at-22-17-15_my_database_1.dump
# Database my_database_1 already exists, skipping creation
# 2023-06-28-at-22-17-15_my_database_1.dump restored to database my_database_1
```

## Retention

After each backup, `.dump` files in `S3_PATH` older than `DELETE_AFTER` are deleted. Other files in the bucket path are left untouched.

## Development

Tests use [bats](https://github.com/bats-core/bats-core) with stubbed `pg_dump`/`aws`/`psql` commands, so no database or AWS account is needed.

```bash
brew install bats-core shellcheck   # or: apt-get install bats shellcheck
make lint test
```
