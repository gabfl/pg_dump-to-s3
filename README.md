# pg_dump-to-s3

Automatically dump and archive PostgreSQL backups to Amazon S3.

## Requirements

 - [AWS cli](https://aws.amazon.com/cli): ```pip install awscli```


## Setup

 - Use `aws configure` to store your AWS credentials in `~/.aws` ([read documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-quick-configuration))
 - Rename `pg_dump-to-s3.conf.sample` to `pg_dump-to-s3.conf` and set your PostgreSQL's credentials and the list of databases to back up
 - If your PostgreSQL connection uses a password, you will need to store it in `~/.pgpass` ([read documentation](https://www.postgresql.org/docs/current/static/libpq-pgpass.html))

## Usage

```bash
./pg_to_s3.sh

#  * Backup in progress.,.
#    -> backing up my_database_1...
#       ...database my_database_1 has been backed up
#    -> backing up my_database_2...
#       ...database my_database_2 has been backed up
#  * Deleting old backups...
#    -> Deleting 2018-05-24-at-03-10-01_my_database_1.dump
#    -> Deleting 2018-05-24-at-03-10-01_my_database_2.dump
#
# ...done!
```

## Restore a backup

```bash
pg_restore -d DB_NAME -Fc --clean PATH_TO_YOUR_DB_DUMP_FILE
```