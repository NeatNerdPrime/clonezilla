#!/bin/bash

# Standalone test for configure_dhcpcd_for_live_system

set -e

echo "=== Running DHCPCD Configuration Tests ==="

# Create a temporary directory for mock environment
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Mock /etc/dhcpcd.conf
export SYSCONFDIR="$TEMP_DIR/etc"
mkdir -p "$SYSCONFDIR"
MOCK_DHCPCD_CONF="$SYSCONFDIR/dhcpcd.conf"

# Case 1: dhcpcd.conf with duid enabled and clientid commented out
cat <<EOF > "$MOCK_DHCPCD_CONF"
# Use the DHCP Unique Identifier (DUID) by default
duid

# Use the hardware address of the interface for the Client ID.
#clientid
EOF

# Load functions from ocs-live-hook-functions
export DRBL_SCRIPT_PATH="."
. setup/files/ocs/live-hook/ocs-live-hook-functions

# Run the target function
configure_dhcpcd_for_live_system

# Check results
echo "Verifying modified dhcpcd.conf..."
if grep -q -E '^[[:space:]]*duid' "$MOCK_DHCPCD_CONF"; then
  echo "FAIL: 'duid' was not disabled/commented out!"
  exit 1
fi

if ! grep -q -E '^[[:space:]]*clientid' "$MOCK_DHCPCD_CONF"; then
  echo "FAIL: 'clientid' was not enabled/uncommented!"
  exit 1
fi

# Case 2: dhcpcd.conf with duid already disabled and clientid missing entirely
cat <<EOF > "$MOCK_DHCPCD_CONF"
# Use the DHCP Unique Identifier (DUID) by default
#duid
EOF

# Run again
configure_dhcpcd_for_live_system

if ! grep -q -E '^[[:space:]]*clientid' "$MOCK_DHCPCD_CONF"; then
  echo "FAIL: 'clientid' was not appended when completely missing!"
  exit 1
fi

echo "PASS: DHCPCD Configuration Tests successful."
exit 0
