#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

export MYSQL_ROOT_PASSWORD='this is an example test password'
export MYSQL_USER='0123456789012345' # "ERROR: 1470  String 'my cool mysql user' is too long for user name (should be no longer than 16)"
export MYSQL_PASSWORD='my cool mysql password'
export MYSQL_DATABASE='my cool mysql database'

cname="mysql-container-$RANDOM-$RANDOM"
cid="$(
	docker run -d \
		-e MYSQL_ROOT_PASSWORD \
		-e MYSQL_USER \
		-e MYSQL_PASSWORD \
		-e MYSQL_DATABASE \
		--name "$cname" \
		"$image"
)"
trap "docker rm -vf $cid > /dev/null" EXIT

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

docker exec "$cname" bash -c "
    if [ ! -f /usr/bin/mysql_ssl_rsa_setup ]; then
	echo warning: no ssl support
	exit 0
    fi
    if [ ! -f /var/lib/mysql/private_key.pem ]; then
	exit 1
    fi
"
