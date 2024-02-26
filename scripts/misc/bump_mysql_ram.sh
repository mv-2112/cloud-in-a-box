#!/bin/bash

declare -i RAMSIZE
declare -i current_ram

RAMSIZE=$1

for each_mysql in $(juju status --format=yaml | yq ' .applications | (keys)[] ' | grep mysql$ )
do
    current_ram=$(juju config $each_mysql profile-limit-memory)
    if [[ $current_ram -ne $1 ]];then
      echo "Setting memory limit for $each_mysql to $1 (currently set to $current)"
      juju config $each_mysql profile-limit-memory=$1
    else 
      echo "Memory limit for $each_mysql is already set to $current_ram ($RAMSIZE requested)"
    fi
done