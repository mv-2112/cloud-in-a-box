use anyhow::{bail, Context, Result};
use chrono::Local;
use clap::{Parser, Subcommand};
use libc::geteuid;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::Command;
use syslog::{Facility, Formatter3164};
use tempfile::NamedTempFile;

const GRUB_FILE: &str = "/etc/default/grub";
const COMMON_PARAM: &str = "iommu=pt";

#[derive(Parser)]
#[command(name = "iommuadm", version, about = "IOMMU administration tool")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Enable,
    Disable,
    Status,
}

fn main() -> Result<()> {
    init_logging()?;

    let cli = Cli::parse();

    require_root()?;
    verify_supported_os()?;
    verify_grub_file()?;

    match cli.command {
        Commands::Enable => enable()?,
        Commands::Disable => disable()?,
        Commands::Status => status()?,
    }

    Ok(())
}

fn init_logging() -> Result<()> {
    let formatter = Formatter3164 {
        facility: Facility::LOG_DAEMON,
        hostname: None,
        process: "iommuadm".into(),
        pid: 0,
    };

    let _ = syslog::unix(formatter);
    Ok(())
}

fn log_info(msg: &str) {
    eprintln!("[INFO] {}", msg);
}

fn require_root() -> Result<()> {
    if unsafe { geteuid() } != 0 {
        bail!("iommuadm must be run as root");
    }
    Ok(())
}

fn verify_supported_os() -> Result<()> {
    let content = fs::read_to_string("/etc/os-release")?;
    if !(content.contains("ID=ubuntu") || content.contains("ID=debian")) {
        bail!("Only Debian and Ubuntu are supported.");
    }

    which::which("update-grub")
        .or_else(|_| which::which("grub-mkconfig"))
        .context("No GRUB update utility found")?;

    Ok(())
}

fn verify_grub_file() -> Result<()> {
    if !Path::new(GRUB_FILE).exists() {
        bail!("{} not found", GRUB_FILE);
    }
    Ok(())
}

fn detect_cpu_vendor() -> Result<&'static str> {
    let cpuinfo = fs::read_to_string("/proc/cpuinfo")?;
    if cpuinfo.contains("GenuineIntel") {
        Ok("intel_iommu=on")
    } else if cpuinfo.contains("AuthenticAMD") {
        Ok("amd_iommu=on")
    } else {
        bail!("Unsupported CPU vendor");
    }
}

fn status() -> Result<()> {
    let content = fs::read_to_string(GRUB_FILE)?;
    let line = extract_cmdline_line(&content)?;

    println!("Current kernel parameters:");
    println!("{}", line);

    if line.contains("intel_iommu=on") || line.contains("amd_iommu=on") {
        println!("IOMMU: ENABLED");
    } else {
        println!("IOMMU: DISABLED");
    }

    Ok(())
}

fn enable() -> Result<()> {
    let vendor = detect_cpu_vendor()?;
    let mut content = fs::read_to_string(GRUB_FILE)?;

    let mut params = extract_params(&content)?;

    let mut changed = false;

    if !params.contains(&vendor.to_string()) {
        params.push(vendor.to_string());
        log_info(&format!("Added {}", vendor));
        changed = true;
    }

    if !params.contains(&COMMON_PARAM.to_string()) {
        params.push(COMMON_PARAM.to_string());
        log_info("Added iommu=pt");
        changed = true;
    }

    if changed {
        write_atomic(&mut content, params)?;
        update_grub()?;
        log_info("IOMMU enabled. Reboot required.");
    } else {
        log_info("IOMMU already enabled.");
    }

    Ok(())
}

fn disable() -> Result<()> {
    let mut content = fs::read_to_string(GRUB_FILE)?;
    let mut params = extract_params(&content)?;

    let original_len = params.len();

    params.retain(|p| {
        p != "intel_iommu=on" && p != "amd_iommu=on" && p != COMMON_PARAM
    });

    if params.len() != original_len {
        write_atomic(&mut content, params)?;
        update_grub()?;
        log_info("IOMMU disabled. Reboot required.");
    } else {
        log_info("IOMMU already disabled.");
    }

    Ok(())
}

fn extract_cmdline_line(content: &str) -> Result<String> {
    for line in content.lines() {
        if line.starts_with("GRUB_CMDLINE_LINUX_DEFAULT=") {
            return Ok(line.to_string());
        }
    }
    bail!("GRUB_CMDLINE_LINUX_DEFAULT not found")
}

fn extract_params(content: &str) -> Result<Vec<String>> {
    let line = extract_cmdline_line(content)?;
    let start = line.find('"').context("Malformed GRUB line")? + 1;
    let end = line.rfind('"').context("Malformed GRUB line")?;
    let cmdline = &line[start..end];

    Ok(cmdline.split_whitespace().map(String::from).collect())
}

fn write_atomic(original: &mut String, params: Vec<String>) -> Result<()> {
    let new_cmdline = params.join(" ");

    let new_content = original
        .lines()
        .map(|line| {
            if line.starts_with("GRUB_CMDLINE_LINUX_DEFAULT=") {
                format!("GRUB_CMDLINE_LINUX_DEFAULT=\"{}\"", new_cmdline)
            } else {
                line.to_string()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
        + "\n";

    let timestamp = Local::now().format("%Y%m%d%H%M%S");
    let backup_path = format!("{}.bak.{}", GRUB_FILE, timestamp);
    fs::copy(GRUB_FILE, backup_path)?;

    let mut tmp = NamedTempFile::new_in("/etc/default")?;
    tmp.as_file_mut().write_all(new_content.as_bytes())?;
    tmp.as_file_mut().sync_all()?;

    tmp.persist(GRUB_FILE)?;

    Ok(())
}

fn update_grub() -> Result<()> {
    if which::which("update-grub").is_ok() {
        Command::new("update-grub").status()?;
    } else {
        Command::new("grub-mkconfig")
            .arg("-o")
            .arg("/boot/grub/grub.cfg")
            .status()?;
    }
    Ok(())
}

