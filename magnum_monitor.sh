#!/usr/bin/env bash



while true
do
MAGNUM_STATUS=$(openstack coe service list -f value -c state)

if [[ $MAGNUM_STATUS == "down" ]]; then
echo "It broke at $(date), restarting..."
sudo kubectl exec -it magnum-0 -c magnum-conductor -n openstack -- ps -ef | grep python | grep -v grep

sudo kubectl exec -i --tty=false magnum-0 -c magnum-conductor -n openstack -- bash << EOF
ps -ef | grep magnum | grep -v grep | awk '{ print \$2 }' > /tmp/$$
kill \$(cat /tmp/$$)
EOF

sleep 10
sudo kubectl exec -it magnum-0 -c magnum-conductor -n openstack -- ps -ef | grep python | grep -v grep
else
  echo "Magnum still running at $(date)"
fi
sleep 10
done
