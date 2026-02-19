# iommuadm

A utility for enabling and disabling iommu on Ubuntu and Debian systems

## Build & Install
cargo build --release
sudo install -m 0755 target/release/iommuadm /usr/sbin/iommuadm

## Packaging as .deb
Install cargo-deb
cargo install cargo-deb

## Add to Cargo.toml
[package.metadata.deb]
maintainer = "Your Name <you@example.com>"
license-file = ["LICENSE", "0"]
depends = "$auto"
section = "admin"
priority = "optional"
assets = [
    ["target/release/iommuadm", "usr/sbin/", "755"]
]

## Build Debian package
cargo deb


Package will appear in:

target/debian/iommuadm_1.1.0_amd64.deb


## Install:

sudo dpkg -i iommuadm_1.1.0_amd64.deb

