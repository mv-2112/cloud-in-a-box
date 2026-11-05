use clap::{Parser, Subcommand};
use regex::Regex;
use std::fs;
use std::io::Read;
use std::path::Path;
use std::process::Command;
use thiserror::Error;

const GRUB_DEFAULT_PATH: &str = "/etc/default/grub";
const GRUB_BACKUP_PATH: &str = "/etc/default/grub.bak";

#[derive(Parser)]
#[command(name = "aspmadm")]
#[command(about = "Manage PCIe ASPM kernel parameter via GRUB")]
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

#[derive(Error, Debug)]
enum AspmError {
    #[error("Permission denied. Please run as root.")]
    PermissionDenied,

    #[error("Failed to read GRUB config: {0}")]
    ReadError(std::io::Error),

    #[error("Failed to write GRUB config: {0}")]
    WriteError(std::io::Error),

    #[error("GRUB_CMDLINE_LINUX_DEFAULT not found")]
    CmdlineNotFound,

    #[error("Failed to update GRUB configuration")]
    GrubUpdateFailed,
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Enable => set_aspm("on"),
        Commands::Disable => set_aspm("off"),
        Commands::Status => status(),
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

fn require_root() -> Result<(), AspmError> {
    if unsafe { libc::geteuid() } != 0 {
        return Err(AspmError::PermissionDenied);
    }
    Ok(())
}

fn set_aspm(state: &str) -> Result<(), AspmError> {
    require_root()?;

    let content =
        fs::read_to_string(GRUB_DEFAULT_PATH).map_err(AspmError::ReadError)?;

    let backup_needed = !Path::new(GRUB_BACKUP_PATH).exists();
    if backup_needed {
        fs::copy(GRUB_DEFAULT_PATH, GRUB_BACKUP_PATH)
            .map_err(AspmError::WriteError)?;
        println!("Backup created at {}", GRUB_BACKUP_PATH);
    }

    let re = Regex::new(r#"^GRUB_CMDLINE_LINUX_DEFAULT="(.*)""#).unwrap();

    let mut new_content = String::new();
    let mut found = false;

    for line in content.lines() {
        if let Some(caps) = re.captures(line) {
            found = true;
            let mut params = caps[1].to_string();

            // Remove existing pcie_aspm parameter
            let re_param = Regex::new(r#"pcie_aspm=\w+"#).unwrap();
            params = re_param.replace_all(&params, "").to_string();

            params = params.trim().to_string();

            if !params.is_empty() {
                params.push(' ');
            }

            params.push_str(&format!("pcie_aspm={}", state));

            new_content.push_str(&format!(
                "GRUB_CMDLINE_LINUX_DEFAULT=\"{}\"\n",
                params
            ));
        } else {
            new_content.push_str(line);
            new_content.push('\n');
        }
    }

    if !found {
        return Err(AspmError::CmdlineNotFound);
    }

    fs::write(GRUB_DEFAULT_PATH, new_content)
        .map_err(AspmError::WriteError)?;

    println!("Set pcie_aspm={}", state);

    update_grub()?;

    println!("GRUB updated successfully. Reboot required.");
    Ok(())
}

fn status() -> Result<(), AspmError> {
    let content =
        fs::read_to_string(GRUB_DEFAULT_PATH).map_err(AspmError::ReadError)?;

    let re = Regex::new(r#"^GRUB_CMDLINE_LINUX_DEFAULT="(.*)""#).unwrap();

    for line in content.lines() {
        if let Some(caps) = re.captures(line) {
            let params = &caps[1];

            if params.contains("pcie_aspm=on") {
                println!("GRUB config: enabled (pcie_aspm=on)");
            } else if params.contains("pcie_aspm=off") {
                println!("GRUB config: disabled (pcie_aspm=off)");
            } else {
                println!("GRUB config: not explicitly configured");
            }
            break;
        }
    }

    // Check running kernel
    if let Ok(mut file) = fs::File::open("/proc/cmdline") {
        let mut cmdline = String::new();
        file.read_to_string(&mut cmdline).unwrap();

        if cmdline.contains("pcie_aspm=on") {
            println!("Running kernel: enabled");
        } else if cmdline.contains("pcie_aspm=off") {
            println!("Running kernel: disabled");
        } else {
            println!("Running kernel: not explicitly configured");
        }
    }

    Ok(())
}

fn update_grub() -> Result<(), AspmError> {
    let commands = vec![
        vec!["update-grub"],
        vec!["grub-mkconfig", "-o", "/boot/grub/grub.cfg"],
        vec!["grub2-mkconfig", "-o", "/boot/grub2/grub.cfg"],
    ];

    for cmd in commands {
        let output = Command::new(cmd[0]).args(&cmd[1..]).output();
        if let Ok(output) = output {
            if output.status.success() {
                return Ok(());
            }
        }
    }

    Err(AspmError::GrubUpdateFailed)
}