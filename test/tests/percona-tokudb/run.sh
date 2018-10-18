#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

export MYSQL_ROOT_PASSWORD='this is an example test password'
export MYSQL_USER='0123456789012345' # "ERROR: 1470  String 'my cool mysql user' is too long for user name (should be no longer than 16)"
export MYSQL_PASSWORD='my cool mysql password'
export MYSQL_DATABASE='my cool mysql database'
TRAP_CMD=""

if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then
	DEFRAG_OLDSTATE=$(cat /sys/kernel/mm/transparent_hugepage/defrag | sed -e 's/.*\[//; s/].*//')
	if [ "${DEFRAG_OLDSTATE}" != "never" -a ! -w /sys/kernel/mm/transparent_hugepage/defrag ]; then
		echo [skipped] due to enabled transparent_hugepage
		exit 0
	elif [ -w /sys/kernel/mm/transparent_hugepage/defrag ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/defrag
		TRAP_CMD+="echo ${DEFRAG_OLDSTATE} > /sys/kernel/mm/transparent_hugepage/defrag; "
		trap "${TRAP_CMD}" EXIT
	fi
fi

if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
	HUGEPAGE_OLDSTATE=$(cat /sys/kernel/mm/transparent_hugepage/enabled | sed -e 's/.*\[//; s/].*//')
	if [ "$HUGEPAGE_OLDSTATE" != "never" -a ! -w /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo [skipped] due to enabled transparent_hugepage
		exit 0
	elif [ -w /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
		TRAP_CMD+="echo ${HUGEPAGE_OLDSTATE} > /sys/kernel/mm/transparent_hugepage/enabled; "
		trap "${TRAP_CMD}" EXIT
	fi
fi

cname="mysql-container-$RANDOM-$RANDOM"
cid="$(
	docker run -d \
		-e INIT_TOKUDB=1 \
		-e MYSQL_ROOT_PASSWORD \
		-e MYSQL_USER \
		-e MYSQL_PASSWORD \
		-e MYSQL_DATABASE \
		--name "$cname" \
		"$image"
)"
TRAP_CMD+="docker rm -vf $cid > /dev/null; "
trap "${TRAP_CMD}" EXIT

mysql() {
	docker run --rm -i \
		--link "$cname":mysql \
		--entrypoint mysql \
		-e MYSQL_PWD="$MYSQL_PASSWORD" \
		"$image" \
		-hmysql \
		-u"$MYSQL_USER" \
		--silent \
		"$@" \
		"$MYSQL_DATABASE"
}

. "$dir/../../retry.sh" --tries 20 "echo 'SELECT 1' | mysql"

echo 'CREATE TABLE test (a INT, b INT, c VARCHAR(255), PRIMARY KEY index_a (a), CLUSTERING KEY index_b (b)) ENGINE=TokuDB' | mysql
[ "$(echo 'SELECT COUNT(*) FROM test' | mysql)" = 0 ]
