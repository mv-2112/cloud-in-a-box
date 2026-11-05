# iommuadm

A utility for enabling and disabling iommu on Ubuntu and Debian systems

## Build & Install
```bash
cargo build --release
sudo install -m 0755 target/release/iommuadm /usr/sbin/iommuadm
```

## Packaging as .deb
Install cargo-deb
```bash
cargo install cargo-deb
```

## Add to Cargo.toml
```toml
[package.metadata.deb]
maintainer = "Your Name <you@example.com>"
license-file = ["LICENSE", "0"]
depends = "$auto"
section = "admin"
priority = "optional"
assets = [
    ["target/release/iommuadm", "usr/sbin/", "755"]
]
```

## Build Debian package
```bash
cargo deb
```

Package will appear in:
```
target/debian/iommuadm_1.1.0_amd64.deb
```

## Install:
```bash
sudo dpkg -i iommuadm_1.1.0_amd64.deb
```
