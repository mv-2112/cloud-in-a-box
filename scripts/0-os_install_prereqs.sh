#!/usr/bin/env bash

snap install openstack 
sunbeam prepare-node-script | bash -x && newgrp snap_daemon