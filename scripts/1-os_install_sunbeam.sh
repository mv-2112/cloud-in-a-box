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
    export type="$1"
    ;;
--)
    shift
    break;;
esac
shift
done

if [[ $type != "s" && $type != "single" ]]; then
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
  pattern='^([0-9]{4}\.[0-9]{1}|[A-Z,a-z]*)\/[A-Z,a-z]*$'
	if [[ $version =~ $pattern ]]; then
		echo "version [$version] looks sensible"
	else
		echo "WARNING: version [$version] does not look like 2023.2/stable as an example (RETURN to continue, CTRL-C to quit)"
    read
    exit 1
	fi
fi


CEPH_DISKS=$(./misc/ceph_disk.sh -i)



if [[ ${snap_info["Rev"]} -le 335 ]]; then
  echo "Generating preseed file..."
  echo "Inserting disks for Ceph config..."
  sunbeam generate-preseed | yq ".microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" > ../sunbeam-preseed.yaml
  sunbeam cluster bootstrap --preseed ../sunbeam-preseed.yaml --role compute --role control --topology single --database single
  sunbeam cluster bootstrap --preseed ../sunbeam-preseed.yaml --role storage --role compute --role control --topology single --database single
else
  echo "Generating empty manifest file..."
  sunbeam manifest generate -f ../sunbeam-manifest.yaml
  echo "Inserting disks for Ceph config..."
  yq -i ".deployment.microceph_config.*.osd_devices = [ "$(./misc/ceph_disk.sh -y)" ]" ../sunbeam-manifest.yaml
  # Fixed after https://github.com/canonical/snap-openstack/pull/224
  # echo "Temporary fix for 456-484 releases..."
  # yq -i ' .software.charms.sunbeam-machine.channel = "'$version'"' ../sunbeam-manifest.yaml
  # for each in placement glance cinder cinder-ceph horizon nova neutron keystone designate
  # do
  #   yq -i ' .software.charms.'$each'-k8s.channel = "'$version'"' ../sunbeam-manifest.yaml
  # done
  # yq -i ' .software.charms.ovn-central-k8s.channel = "23.09/stable"' ../sunbeam-manifest.yaml
  # yq -i ' .software.charms.ovn-relay-k8s.channel = "23.09/stable"' ../sunbeam-manifest.yaml
  # yq -i ' .software.charms.openstack-hypervisor.channel = "'$version'"' ../sunbeam-manifest.yaml
  # Align networks
  management_cidr=$(yq ' .deployment.bootstrap.management_cidr' ../sunbeam-manifest.yaml)
  mask=$(echo $management_cidr | cut -f2 -d/)
  range=$(echo $management_cidr | cut -f1 -d/)
  if [[ $mask -eq 24 ]]; then
    base_range=$(echo $range | cut -f-3 -d.)
    metallb_range="$base_range.20-$base_range.69"
    yq -i ' .deployment.addons.metallb = "'$metallb_range'"' ../sunbeam-manifest.yaml
    yq -i ' .deployment.k8s-addons.loadbalancer = "'$base_range'.70/24"' ../sunbeam-manifest.yaml
  else
    echo "WARNING - your network is not a simple home style /24 - check the metallb and management ranges are the same"
  fi

  # Reconstruct .software.charms in the manifeset, i.e, uncomment it and insert.
  yq ' . | footComment ' ../sunbeam-manifest.yaml > ../comment_bits.yaml
  yq -i '.software.charms += (load("../comment_bits.yaml") | .charms)' ../sunbeam-manifest.yaml
  rm ../comment_bits.yaml
  
  sunbeam cluster bootstrap --manifest ../sunbeam-manifest.yaml $type
fi




juju switch openstack
result=$(juju status --format json | yq ' .offers."cinder-ceph" | ."active-connected-count" ')
if [[ $result -ne 1 ]]; then
  juju integrate admin/controller.microceph cinder-ceph
fi
echo "Watch juju status until connected"
