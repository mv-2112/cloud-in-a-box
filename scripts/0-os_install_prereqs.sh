#!/usr/bin/env bash
sudo snap install yq

snap info openstack | yq '.channels'
read -p "You have selected [$1] - press any key to continue..."

if [[ ! -z $1 ]]; then
  sudo snap install openstack --channel $1
else
  sudo snap install openstack
fi
sunbeam prepare-node-script | bash -x && newgrp snap_daemon
