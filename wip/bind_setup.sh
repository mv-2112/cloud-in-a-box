#!/usr/bin/env bash

# ==============================================================================
# BIND9 Forwarding Configuration Script
# Target: Ubuntu/Debian BIND9 installations
# Function: Configures recursion, trusted ACLs, and upstream DNS forwarders.
# ==============================================================================

# --- Configuration Variables ---
CONF="/etc/bind/named.conf.options"
BACKUP="$CONF.orig"

# Define authorized network ranges (ACL)
TRUSTED_NET="192.168.1.0/24"

# Define upstream DNS providers (e.g., Cloudflare, Google, or ISP)
FWD_PRIMARY="1.1.1.1"
FWD_SECONDARY="1.0.0.1"

# --- Initialization ---
# Ensure BIND9 and DNS tools (for dig) are installed
sudo apt update && sudo apt install -y bind9 dnsutils
[ ! -f "$BACKUP" ] && sudo cp "$CONF" "$BACKUP"

# --- Step 1: Forwarders Configuration ---
# Replaces the default forwarders block with our variables to ensure
# queries not handled locally are sent to chosen high-performance upstreams.
sudo sed -i "/forwarders {/,/};/c \        forwarders {\n                $FWD_PRIMARY;\n                $FWD_SECONDARY;\n        };" "$CONF"

# --- Step 2: Global Resolution Logic ---
# recursion yes: Allows the server to query on behalf of clients.
# forward only: Forces use of forwarders; bypasses root hints for speed/privacy.
grep -q "recursion yes;" "$CONF" || sudo sed -i '/directory "/a \        recursion yes;\n        forward only;' "$CONF"

# --- Step 2b: Interface Listening ---
# Configures BIND to listen on all available network interfaces (port 53).
# We use 'any;' to ensure external clients in the 'trusted' ACL can connect.
if grep -q "listen-on {" "$CONF"; then
    # If the line exists, update it to 'any;'
    sudo sed -i 's/listen-on {.*};/listen-on { any; };/' "$CONF"
else
    # If it doesn't exist, insert it after the directory line
    sudo sed -i '/directory "/a \        listen-on { any; };' "$CONF"
fi

# Open DNS ports (UDP and TCP) in the firewall
if command -v ufw &> /dev/null; then
    sudo ufw allow Bind9
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --add-service=dns --permanent
    sudo firewall-cmd --reload
fi

# --- Step 3: Security & Access Control ---
# Defines the 'trusted' ACL before the options block for structural correctness.
if ! grep -q "acl \"trusted\"" "$CONF"; then
    sudo sed -i "/options {/i acl \"trusted\" {\n        $TRUSTED_NET;\n        localhost;\n        localnets;\n};\n" "$CONF"
fi

# --- Step 4: Restrict Query Access ---
# Enforces the ACL to prevent the server from participating in 
# [DNS amplification attacks](https://www.cloudflare.com).
if ! grep -q "allow-query { trusted; };" "$CONF"; then
    sudo sed -i '/options {/a \        allow-query { trusted; };' "$CONF"
fi

# --- Step 5: Validation & Deployment ---
# Use the [named-checkconf utility](https://linux.die.net) to verify syntax.
if sudo named-checkconf "$CONF"; then
    echo "SUCCESS: Syntax check passed. Reloading BIND9..."
    sudo systemctl restart bind9
    
    # --- Step 6: Functional Testing ---
    # Perform a test lookup against the local instance to verify forwarding works.
    echo "Testing DNS resolution for google.com..."
    sleep 2 # Give BIND a moment to initialize
    if dig +short @127.0.0.1 google.com > /dev/null; then
        echo "VERIFIED: BIND9 is successfully resolving via $FWD_PRIMARY/$FWD_SECONDARY"
    else
        echo "WARNING: BIND9 restarted but failed to resolve google.com. Check logs with 'journalctl -u bind9'"
    fi
else
    echo "CRITICAL ERROR: Configuration syntax is invalid!"
    echo "Action: Reverting to original backup at $BACKUP"
    sudo cp "$BACKUP" "$CONF"
    exit 1
fi

# --- Step 7: Update Host Resolver (Netplan via Snap yq) ---
# Safely updates YAML structure using a distro-verified binary.

# Install yq via snap if not present
# not yet working right
# if ! command -v yq &> /dev/null; then
#     echo "Installing yq via snap..."
#     sudo snap install yq
# fi

# # Locate the primary Netplan configuration
# NET_CONF=$(ls /etc/netplan/*.yaml | head -n 1)

# if [ -n "$NET_CONF" ]; then
#     echo "Updating $NET_CONF with yq..."
#     sudo cp "$NET_CONF" "$NET_CONF.bak"

#     # Use [yq](https://snapcraft.io) to set the nameserver to localhost.
#     # The '*' wildcard ensures we catch the interface name regardless of naming convention.
#     sudo yq -i '.network.ethernets.*.nameservers.addresses = ["127.0.0.1"]' "$NET_CONF"
    
#     # We also need to disable DHCP DNS overrides if applicable
#     sudo yq -i '.network.ethernets.*.dhcp4-overrides.use-dns = false' "$NET_CONF"

#     echo "Applying Netplan configuration..."
#     sudo netplan apply
# else
#     echo "No Netplan YAML found to update."
# fi

# --- Final Verification ---
echo "System Resolver Status:"
resolvectl status | grep -A 2 "DNS Servers"

