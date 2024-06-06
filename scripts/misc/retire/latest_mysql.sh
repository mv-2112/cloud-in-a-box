#!/usr/bin/env bash

channel="8.0/stable"
rchannel="8.0/stable"


if [[ ! -z $1 ]]; then
	channel=$1
fi

if [[ ! -z $2 ]]; then
        rchannel=$2
fi

for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql$ ); do juju refresh $each_mysql --channel $channel; done
for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql-router$ ); do juju refresh $each_mysql --channel $rchannel; done

