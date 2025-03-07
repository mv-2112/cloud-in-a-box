# cloud-in-a-box
Quick and dirty cloud in a box, with supporting infrastructure


## Getting started
This is intended to be easy, so the requirements are simple.
- You need a Ubuntu install (desktop is ok).
- You need a blank extra drive
- You probably need 16GB or more
- You will need an internet connection
- You'll need lots of cpu cores

This was developed on a HP z640 with 2x Xeon E5-2640v4 (40 cores total) with 80GB RAM, an NVMe boot disk, and 4x 480GB SSD's.

Install Ubuntu onto NVMe disk

During the install, SSD 1, 2,3, and 4 will be used for Ceph.


## Initial install

Navigate to the root directory of the repo and reference the install script.

- `./install.sh`
- After it completes, `cat install.sh` to see the remaining steps.

## Removal

Navigate to the root directory of the repo and uninstall.sh
