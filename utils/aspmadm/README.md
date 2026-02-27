# aspmadm

**aspmadm** is a lightweight Rust utility for Linux systems that enables, disables, or checks the status of PCIe Active State Power Management (ASPM) by modifying the GRUB kernel command line parameter:

```
pcie_aspm=on
pcie_aspm=off
```

It safely updates:

```
GRUB_CMDLINE_LINUX_DEFAULT="..."
```

in `/etc/default/grub`, and regenerates the GRUB configuration.

---

## ✨ Features

- Enable PCIe ASPM (`pcie_aspm=on`)
- Disable PCIe ASPM (`pcie_aspm=off`)
- Show current ASPM status
- Automatic backup of `/etc/default/grub`
- Supports common GRUB update commands:
  - `update-grub`
  - `grub-mkconfig -o /boot/grub/grub.cfg`
  - `grub2-mkconfig -o /boot/grub2/grub.cfg`

---

## 📦 Requirements

- Linux system using GRUB (GRUB 2)
- Root privileges (required to modify `/etc/default/grub`)
- Rust toolchain (for building)

Install Rust from:
https://www.rust-lang.org/tools/install

---

## 🚀 Installation

### Build from Source

```bash
git clone https://example.com/aspmadm.git
cd aspmadm
cargo build --release
```

Binary will be available at:

```
target/release/aspmadm
```

Move it into your path:

```bash
sudo cp target/release/aspmadm /usr/local/bin/
```

---

## 📖 Usage

### Disable PCIe ASPM

```bash
sudo aspmadm disable
```

This sets:

```
pcie_aspm=off
```

in `GRUB_CMDLINE_LINUX_DEFAULT`.

---

### Enable PCIe ASPM

```bash
sudo aspmadm enable
```

This sets:

```
pcie_aspm=on
```

---

### Check Status

```bash
aspmadm status
```

Example output:

```
GRUB config: disabled (pcie_aspm=off)
Running kernel: disabled
```

or

```
GRUB config: enabled (pcie_aspm=on)
Running kernel: enabled
```

or

```
GRUB config: not explicitly configured
Running kernel: not explicitly configured
```

---

## 🔄 What It Does Internally

1. Reads `/etc/default/grub`
2. Parses `GRUB_CMDLINE_LINUX_DEFAULT`
3. Adds or replaces `pcie_aspm=` parameter
4. Creates a backup:
   ```
   /etc/default/grub.bak
   ```
5. Runs appropriate GRUB update command

---

## 🔐 Permissions

You must run `enable` or `disable` as root:

```bash
sudo aspmadm enable
sudo aspmadm disable
```

`status` does not require root.

---

## 🏗 Packaging

### Create a Debian Package

Install cargo-deb:

```bash
cargo install cargo-deb
```

Add to `Cargo.toml`:

```toml
[package.metadata.deb]
maintainer = "Your Name"
license-file = ["LICENSE", "0"]
depends = "$auto"
section = "admin"
priority = "optional"
assets = [
    ["target/release/aspmadm", "usr/bin/", "755"],
    ["README.md", "usr/share/doc/aspmadm/README", "644"],
]
```

Build package:

```bash
cargo deb
```

---

### Create an RPM Package

Install cargo-rpm:

```bash
cargo install cargo-rpm
```

Initialize:

```bash
cargo rpm init
```

Build:

```bash
cargo rpm build
```

---

## 🧪 Verifying After Reboot

After running enable/disable:

```bash
sudo reboot
```

Then verify:

```bash
cat /proc/cmdline | grep pcie_aspm
```

Or:

```bash
aspmadm status
```

---

## ⚠️ Notes

- Some hardware may not support ASPM.
- BIOS/UEFI settings may override kernel parameters.
- Disabling ASPM may increase power consumption.
- Enabling ASPM may cause instability on certain devices.

---

## 📜 License

This project is released under the **Creative Commons Zero v1.0 Universal (CC0 1.0)** license.

You are free to:

- Use
- Modify
- Distribute
- Sell
- Re-license

Without restriction.

Full license text:
https://creativecommons.org/publicdomain/zero/1.0/

---

## 🤝 Contributing

Pull requests are welcome.

If you’d like to extend functionality (e.g., support systemd-boot, dracut detection, or dry-run mode), feel free to submit improvements.

---

## 🧰 Future Improvements

- `--dry-run` mode
- `--force` override
- systemd-boot support
- Configurable GRUB path
- Logging support
- UEFI detection

---

## 🧑‍💻 Author

Created for Linux power management control using Rust.