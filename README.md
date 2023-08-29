# pg_dump-to-s3

Automatically dump and archive PostgreSQL backups to Amazon S3.

## Requirements

 - [AWS cli](https://aws.amazon.com/cli): ```pip install awscli```

## Setup

 - Use `aws configure` to store your AWS credentials in `~/.aws` ([read documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-quick-configuration))
 - Edit `.conf` and set your PostgreSQL's credentials and the list of databases to back up. Optionally, the file can be moved to the home directory in `~/.pg_dump-to-s3.conf`.
 - If your PostgreSQL connection uses a password, you will need to store it in `~/.pgpass` ([read documentation](https://www.postgresql.org/docs/current/static/libpq-pgpass.html))

## Usage

```bash
./pg_dump-to-s3.sh

#  * Backup in progress.,.
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
