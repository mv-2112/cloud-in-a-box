#!/usr/bin/env bash

declare -A snap_info 

function get_info {
  
  snap list openstack > /tmp/$$

  col_names=$(head -1 /tmp/$$)
  col_data=( $(tail -1 /tmp/$$) )

  n=0
  for each_key in $( echo $col_names )
  do
    snap_info[$each_key]=${col_data[$n]}
    echo "$each_key: ${snap_info[$each_key]}"
    n=$((n+1))
  done

  rm /tmp/$$
}


# Set up our precursor variables and figure out what we are doing.

get_info

showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF  
Usage: ./$0 -v <release> [-sh]
Install Sunbeam in a managed way. 

-h, -help,          --help                  Display help

-v, -version,       --version               Set and Download specific version of Sunbeam/Openstack components

-t, -type,          --type                  Installation type s=single, m=multinode (default: s)

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


export version=${snap_info["Tracking"]}
export type="s"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,version:,type:" -o "hv:t:" -a -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters 
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
case "$1" in
-h|--help) 
    showHelp
    exit 0
    ;;
-v|--version) 
    shift
    export version="$1"
    ;;
-t|--type)
    shift
    export single="$1"
    ;;
--)
    shift
    break;;
esac
shift
done

if [[ $type != "s" ]]; then
	echo "Configuring Multinode"
	echo "Not implemented yet... exiting"
	exit 1
else
	echo "Configuring as single node installation"
	type="--role storage --role compute --role control --topology single --database single"
fi


if [[ $version == "default" ]]; then
	echo "Setting default safety version of 2023.2/stable for charms"
	version="2023.2/stable"
else
	#check format looks sensible
	if [[ $version =~ ^(\d{4}\.\d{1}|[A-Z,a-z]*)\/[A-Z,a-z]*$ ]]; then
		echo "version [$version] looks sensible"
	else
		echo "version [$version] does not look like 2023.2/stable as an example"
	fi
fi


CEPH_DISKS=$(./misc/ceph_disk.sh -i)




# echo "Tuning mysql to aim to reduce OOMkiller impact..."
# yq -i ".software.mysql-k8s.config.profile-limit-memory=4096 " ../sunbeam-manifest.yaml

# Lets go all in now on the single bootstrap now its faster
# sunbeam cluster bootstrap --accept-defaults

# We removed --role control from next line as now seems to be inferred.
# Post 385/386 we've moved to manifests
if [[ ${snap_info["Rev"]} -le 335 ]]; then
  echo "Generating preseed file..."
  echo "Inserting disks for Ceph config..."
  sunbeam generate-preseed | yq ".microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" > ../sunbeam-preseed.yaml
  sunbeam cluster bootstrap --preseed ../sunbeam-preseed.yaml $type
else
  echo "Generating empty manifest file..."
  sunbeam manifest generate -f ../sunbeam-manifest.yaml
  echo "Inserting disks for Ceph config..."
  yq -i ".deployment.microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" ../sunbeam-manifest.yaml
  echo "Temporary fix for 456-481 releases..."
  yq -i ' .software.charms.sunbeam-machine.channel = "'$version'"' ../sunbeam-manifest.yaml
  for each in placement glance cinder cinder-ceph horizon nova neutron keystone 
  do
    yq -i ' .software.charms.'$each'-k8s.channel = "'$version'"' ../sunbeam-manifest.yaml
  done
  sunbeam cluster bootstrap --manifest ../sunbeam-manifest.yaml $type
fi

# ./misc/ease_liveness_tests.sh


juju switch openstack
juju integrate admin/controller.microceph cinder-ceph
echo "Watch juju status until connected"
