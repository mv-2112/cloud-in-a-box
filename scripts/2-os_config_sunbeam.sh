#!/usr/bin/env bash

AUTHDIR="../auth"

if [ ! -d "$AUTHDIR" ]; then
	mkdir $AUTHDIR
fi

sunbeam configure --accept-defaults --openrc $AUTHDIR/demo-openrc
sunbeam openrc > $AUTHDIR/admin_openrc
sunbeam dashboard-url
source $AUTHDIR/admin_openrc 
echo $OS_PASSWORD
echo $OS_USER_DOMAIN_NAME
