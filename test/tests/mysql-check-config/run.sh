#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

serverImage="$("$dir/../image-name.sh" librarytest/mysql-initdb "$image")"
"$dir/../docker-build.sh" "$dir" "$serverImage" <<EOD
FROM $image
RUN echo '!includedir /tmp/conf.d/' >> \$(ls /etc/mysql/my.cnf /etc/my.cnf | head -1)
EOD

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
		-v "$dir:/tmp/conf.d" \
		--name "$cname" \
		"$serverImage"
)"
trap "docker rm -vf $cid > /dev/null" EXIT

while docker ps -f "name=$cname" | grep -q "$cname"; do
	sleep 1
done

docker logs "$cname" 2>&1 \
	| grep -q 'ERROR: mysqld failed while attempting to check config'
