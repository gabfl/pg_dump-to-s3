# pg_dump-to-s3

Automatically dump and archive PostgreSQL backups to Amazon S3.

## Requirements

 - [AWS cli](https://aws.amazon.com/cli): ```pip install awscli```

## Setup

 - Use `aws configure` to store your AWS credentials in `~/.aws` ([read documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-quick-configuration))
 - Edit `.conf` and set your PostgreSQL's credentials and the list of databases to back up
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
pg_restore -d DB_NAME -Fc --clean PATH_TO_YOUR_DB_DUMP_FILE
```