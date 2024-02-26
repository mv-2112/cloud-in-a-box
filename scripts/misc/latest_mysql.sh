#!/usr/bin/env bash

for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql$ ); do juju refresh $each_mysql --channel 8.0/edge; done
for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql-router$ ); do juju refresh $each_mysql --channel 8.0/edge; done

