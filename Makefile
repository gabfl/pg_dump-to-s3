.PHONY: test lint

test:
	bats test/

lint:
	shellcheck -x pg_dump-to-s3.sh pg_restore-from-s3.sh test/stubs/_stub
