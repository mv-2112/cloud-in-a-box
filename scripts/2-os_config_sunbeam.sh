#!/usr/bin/env bash

sunbeam configure --accept-defaults --openrc demo-openrc
sunbeam openrc > admin_openrc
sunbeam dashboard-url
source ./admin_openrc 
echo $OS_PASSWORD
echo $OS_USER_DOMAIN_NAME