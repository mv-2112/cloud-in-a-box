#!/usr/bin/env bash

for each in $(sunbeam enable | sed -e '1,/Commands:/ d' | awk '{ print $1 }')
do
  read -r -p "Install feature $each? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            if [[ "$each" == "dns" ]]; then
              sunbeam enable $each --nameservers "ns1.example.com. ns2.example.com."
            else 
              sunbeam enable $each
            fi
            ;;
        *)
            echo -e "\c"
            ;;
    esac
done

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
