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

const ENABLE_PARAMS: [&str; 3] = [
    "default_hugepagesz=1G",
    "hugepagesz=1G",
    "hugepages=64",
];

#[derive(Parser)]
#[command(name = "hugepagesadm", version, about = "HugePages administration tool")]
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
        process: "hugepagesadm".into(),
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
        bail!("hugepagesadm must be run as root");
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

fn status() -> Result<()> {
    let content = fs::read_to_string(GRUB_FILE)?;
    let params = extract_params(&content)?;

    println!("Configured kernel parameters:");
    for p in &params {
        if p.starts_with("huge") || p.starts_with("default_hugepagesz") {
            println!("  {}", p);
        }
    }

    let meminfo = fs::read_to_string("/proc/meminfo")?;
    for line in meminfo.lines() {
        if line.starts_with("HugePages_") || line.starts_with("Hugepagesize") {
            println!("{}", line);
        }
    }

    Ok(())
}

fn enable() -> Result<()> {
    let mut content = fs::read_to_string(GRUB_FILE)?;
    let mut params = extract_params(&content)?;

    let mut changed = false;

    for p in ENABLE_PARAMS {
        if !params.iter().any(|x| x == p) {
            params.push(p.to_string());
            log_info(&format!("Added {}", p));
            changed = true;
        }
    }

    if changed {
        write_atomic(&mut content, params)?;
        update_grub()?;
        log_info("HugePages enabled. Reboot required.");
    } else {
        log_info("HugePages already configured.");
    }

    Ok(())
}

fn disable() -> Result<()> {
    let mut content = fs::read_to_string(GRUB_FILE)?;
    let mut params = extract_params(&content)?;

    let original_len = params.len();

    params.retain(|p| {
        !(p.starts_with("hugepages=")
            || p.starts_with("hugepagesz=")
            || p.starts_with("default_hugepagesz="))
    });

    if params.len() != original_len {
        write_atomic(&mut content, params)?;
        update_grub()?;
        log_info("HugePages parameters removed. Reboot required.");
    } else {
        log_info("HugePages already disabled.");
    }

    Ok(())
}

fn extract_params(content: &str) -> Result<Vec<String>> {
    for line in content.lines() {
        if line.starts_with("GRUB_CMDLINE_LINUX_DEFAULT=") {
            let start = line.find('"').context("Malformed GRUB line")? + 1;
            let end = line.rfind('"').context("Malformed GRUB line")?;
            let cmdline = &line[start..end];
            return Ok(cmdline.split_whitespace().map(String::from).collect());
        }
    }
    bail!("GRUB_CMDLINE_LINUX_DEFAULT not found")
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

