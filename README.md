# cloud-in-a-box
Quick and dirty cloud in a box, with supporting infrastructure


## Getting started
This is intended to be easy, so the requirements are simple.
- You need a Ubuntu install (desktop is ok).
- You need a blank extra drive
- You probably need 16GB or more
- You will need an internet connection
- You'll need lots of cpu cores

This was developed on a HP z640 with 2x Xeon E5-2609v3 (12 cores total) with 80GB RAM, and 4x 480GB SSD's.

Install Ubuntu onto SSD 1

During the install, SSD 2,3, and 4 will be used for Ceph.


## Initial install

Navigate to the scripts directory and run each of the install scripts in turn.

./0-os_install_prereqs.sh
./1-os_install_sunbeam.sh (accept the defaults when prompted)

Example output:

$ sunbeam cluster bootstrap --role storage --role compute --role control
Management networks shared by hosts (CIDRs, separated by comma) (192.168.68.0/24): 
MetalLB address allocation range (supports multiple ranges, comma separated) (10.20.21.10-10.20.21.20): 
Disks to attach to MicroCeph (): /dev/disk/by-id/wwn-0x50026b7381077cde,/dev/disk/by-id/wwn-0x50026b7381077d0b,/dev/disk/by-id/wwn-0x50026b7381077d10
Node has been bootstrapped with roles: storage, compute, control

If you get an Error: {'return-code': 0} from the MicroCeph install, you may need to clear any disk headers on SSD2,3 and 4.

e.g:- 
wipefs -af /dev/disk/by-id/wwn-0x50026b7381077cde
wipefs -af /dev/disk/by-id/wwn-0x50026b7381077d0b
wipefs -af /dev/disk/by-id/wwn-0x50026b7381077d10

You will need to use juju status to check Ceph has then correctly linked to Openstack. 

Once this has happened, configure Openstack.

./2-os_config_sunbeam.sh 


## Removal

Navigate to the scripts directory and run 99-os_cleanup.sh