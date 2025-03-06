#!/usr/bin/env bash

# Ensure HAProxy is installed on Ubuntu Desktop
dpkg -s haproxy &> /dev/null || {
    sudo apt install -y haproxy
}

# Ensure Curl is installed on Ubuntu Desktop
dpkg -s curl &> /dev/null || {
    sudo apt install -y curl
}



EXTERNAL_IP=$( curl -s 'https://api.ipify.org' ) && echo "External IP: $EXTERNAL_IP"


if [[ $(openstack loadbalancer list -f csv | grep jenkins | wc -l) -eq 1 ]]; then
  JENKINS_LB_ID=$(openstack loadbalancer list -f csv | grep jenkins | cut -d, -f1 | tr -d '"')
  echo "Identified Jenkins Loadbalancer: $JENKINS_LB_ID"
else
  echo "Unable to identify Jenkins Loadbalancer"
  exit 1
fi

INTERNAL_LB_IP=$(openstack loadbalancer show $JENKINS_LB_ID -f value -c vip_address)
EXTERNAL_LB_IP=$(openstack floating ip list --fixed-ip-address $INTERNAL_LB_IP -f value -c 'Floating IP Address')
echo "Matched $INTERNAL_LB_IP to floating IP $EXTERNAL_LB_IP"

sed "s/@@@@@/$EXTERNAL_LB_IP/" ./haproxy.cfg.fragment > ./haproxy.cfg.populated 
cat /etc/haproxy/haproxy.cfg ./haproxy.cfg.populated > ./haproxy.cfg
rm ./haproxy.cfg.populated 

sudo cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup$$
sudo cp ./haproxy.cfg /etc/haproxy/haproxy.cfg

sudo systemctl restart haproxy

echo "If the aboves not errored, you should now be able to access your jenkins instance at http://$EXTERNAL_IP:8080" 
