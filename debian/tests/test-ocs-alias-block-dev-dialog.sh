#!/bin/bash
# Standalone test for ocs-functions ask_use_ocs_alias_blkdev & reset_use_ocs_alias_blkdev functions, and clonezilla reset option.

set -e

echo "=== Running ask_use_ocs_alias_blkdev Dialog and Reset Tests ==="

# Clean up any potential state file from previous system/interactive runs
rm -f /tmp/use_ocs_alias_blkdev.state /run/live/use_ocs_alias_blkdev.state

# Mock some required global variables/messages first
msg_nchc_free_software_labs="NCHC Free Software Labs"
msg_nchc_clonezilla="Clonezilla"
msg_ocs_alias_block_dev_des="Choose if you want to use Clonezilla alias block device name"
DIA_ESC=""

# Load ask_use_ocs_alias_blkdev function from scripts/sbin/ocs-functions
FUNC_CODE=$(sed -n '/^ask_use_ocs_alias_blkdev() {/,/^} # end of ask_use_ocs_alias_blkdev/p' scripts/sbin/ocs-functions)
if [ -z "$FUNC_CODE" ]; then
  echo "FAIL: Could not extract ask_use_ocs_alias_blkdev from ocs-functions"
  exit 1
fi
eval "$FUNC_CODE"

# Load reset_use_ocs_alias_blkdev function from scripts/sbin/ocs-functions
RESET_FUNC_CODE=$(sed -n '/^reset_use_ocs_alias_blkdev() {/,/^} # end of reset_use_ocs_alias_blkdev/p' scripts/sbin/ocs-functions)
if [ -z "$RESET_FUNC_CODE" ]; then
  echo "FAIL: Could not extract reset_use_ocs_alias_blkdev from ocs-functions"
  exit 1
fi
eval "$RESET_FUNC_CODE"

# Test 1: Skip if DIA is empty
echo "Testing behavior when DIA is empty..."
DIA=""
use_ocs_alias_blkdev="default"
ask_use_ocs_alias_blkdev_done="no"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "default" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev to remain unchanged, but got '$use_ocs_alias_blkdev'"
  exit 1
fi
if [ "$ask_use_ocs_alias_blkdev_done" != "no" ]; then
  echo "FAIL: Expected ask_use_ocs_alias_blkdev_done to remain 'no', but got '$ask_use_ocs_alias_blkdev_done'"
  exit 1
fi

# Test 2: Skip if already done
echo "Testing behavior when already done..."
DIA="mock_dia"
use_ocs_alias_blkdev="default"
ask_use_ocs_alias_blkdev_done="yes"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "default" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev to remain unchanged, but got '$use_ocs_alias_blkdev'"
  exit 1
fi

# Test 3: Prompting and selecting -uoab (with /tmp/ fallback)
echo "Testing selection of -uoab with fallback state_file..."
DIA="mock_dia"
mock_dia() {
  # Write "-uoab" to the output descriptor (which is 2 in our function)
  echo "-uoab" >&2
  return 0
}
export -f mock_dia

use_ocs_alias_blkdev="default"
ask_use_ocs_alias_blkdev_done="no"

# Mock ocs-live.conf path
CONF_DIR=$(mktemp -d)
trap "rm -rf $CONF_DIR; rm -f /tmp/use_ocs_alias_blkdev.state /run/live/use_ocs_alias_blkdev.state" EXIT
# Touch the config file first so -f check succeeds, simulating clonezilla live environment
touch "$CONF_DIR/ocs-live-test.conf"

# Override /etc/ocs/ocs-live.conf to use our temp directory for the test
# We replace the literal /etc/ocs/ocs-live.conf with our temp file in the eval code for testing
TEST_FUNC_CODE="${FUNC_CODE//\/etc\/ocs\/ocs-live.conf/$CONF_DIR/ocs-live-test.conf}"
eval "$TEST_FUNC_CODE"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "yes" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev='yes', but got '$use_ocs_alias_blkdev'"
  exit 1
fi
if [ "$ask_use_ocs_alias_blkdev_done" != "yes" ]; then
  echo "FAIL: Expected ask_use_ocs_alias_blkdev_done='yes', but got '$ask_use_ocs_alias_blkdev_done'"
  exit 1
fi

# Verify fallback state file was created and contains "yes"
if [ ! -f "/tmp/use_ocs_alias_blkdev.state" ]; then
  echo "FAIL: Expected /tmp/use_ocs_alias_blkdev.state to exist"
  exit 1
fi
STATE_CONTENT=$(cat "/tmp/use_ocs_alias_blkdev.state")
if [ "$STATE_CONTENT" != "yes" ]; then
  echo "FAIL: Expected state file content to be 'yes', but got '$STATE_CONTENT'"
  exit 1
fi

# Test 4: Skip when state file exists
echo "Testing behavior when state file already exists..."
DIA="mock_dia"
use_ocs_alias_blkdev="default"
ask_use_ocs_alias_blkdev_done="no"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "yes" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev='yes' (loaded from state file), but got '$use_ocs_alias_blkdev'"
  exit 1
fi
if [ "$ask_use_ocs_alias_blkdev_done" != "yes" ]; then
  echo "FAIL: Expected ask_use_ocs_alias_blkdev_done='yes', but got '$ask_use_ocs_alias_blkdev_done'"
  exit 1
fi

# Test 5: Testing with mock /run/live directory
echo "Testing behavior with mock /run/live directory..."
rm -f /tmp/use_ocs_alias_blkdev.state
ask_use_ocs_alias_blkdev_done="no"
use_ocs_alias_blkdev="default"

MOCK_RUN_LIVE=$(mktemp -d)
# Substitute /run/live with our temp directory in the function
MOCK_RUN_LIVE_FUNC_CODE="${TEST_FUNC_CODE//\/run\/live/$MOCK_RUN_LIVE}"
eval "$MOCK_RUN_LIVE_FUNC_CODE"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "yes" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev='yes' (with mock /run/live), but got '$use_ocs_alias_blkdev'"
  exit 1
fi

# Verify state file was created in mock run live directory
if [ ! -f "$MOCK_RUN_LIVE/use_ocs_alias_blkdev.state" ]; then
  echo "FAIL: Expected mock run live state file to exist"
  exit 1
fi
rm -rf "$MOCK_RUN_LIVE"

# Test 6: Prompting and selecting " " (space)
echo "Testing selection of empty/space (defaulting to no)..."
DIA="mock_dia_space"
mock_dia_space() {
  echo " " >&2
  return 0
}
export -f mock_dia_space

# Clean up state file and truncate the config file to force prompt
rm -f /tmp/use_ocs_alias_blkdev.state
echo "" > "$CONF_DIR/ocs-live-test.conf"

# Reset variables to prevent test state-leaks
ask_use_ocs_alias_blkdev_done="no"
use_ocs_alias_blkdev="default"
# Change mock DIA in the eval'd code
eval "${TEST_FUNC_CODE//\$DIA/mock_dia_space}"

ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "no" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev='no', but got '$use_ocs_alias_blkdev'"
  exit 1
fi

CONF_CONTENT=$(cat "$CONF_DIR/ocs-live-test.conf")
if [[ "$CONF_CONTENT" != *'use_ocs_alias_blkdev="no"'* ]]; then
  echo "FAIL: Expected conf file to update to use_ocs_alias_blkdev=\"no\", but got: $CONF_CONTENT"
  exit 1
fi

# Test 7: Skip when already configured in ocs-live.conf
echo "Testing skip when already configured in ocs-live.conf..."
rm -f /tmp/use_ocs_alias_blkdev.state
ask_use_ocs_alias_blkdev_done="no"
use_ocs_alias_blkdev="default"

# ocs-live-test.conf currently contains 'use_ocs_alias_blkdev="no"'
eval "$TEST_FUNC_CODE"
ask_use_ocs_alias_blkdev

if [ "$use_ocs_alias_blkdev" != "no" ]; then
  echo "FAIL: Expected use_ocs_alias_blkdev='no' (loaded from ocs-live.conf), but got '$use_ocs_alias_blkdev'"
  exit 1
fi
if [ "$ask_use_ocs_alias_blkdev_done" != "yes" ]; then
  echo "FAIL: Expected ask_use_ocs_alias_blkdev_done='yes', but got '$ask_use_ocs_alias_blkdev_done'"
  exit 1
fi

# Test 8: Unit test reset_use_ocs_alias_blkdev function directly
echo "Unit testing reset_use_ocs_alias_blkdev function..."
touch /tmp/use_ocs_alias_blkdev.state
# Mock ocs-live.conf
echo 'use_ocs_alias_blkdev="yes"' > "$CONF_DIR/ocs-live-test.conf"

TEST_RESET_FUNC_CODE="${RESET_FUNC_CODE//\/etc\/ocs\/ocs-live.conf/$CONF_DIR/ocs-live-test.conf}"
eval "$TEST_RESET_FUNC_CODE"

reset_use_ocs_alias_blkdev

if [ -f "/tmp/use_ocs_alias_blkdev.state" ]; then
  echo "FAIL: Expected /tmp/use_ocs_alias_blkdev.state to be deleted by reset function"
  exit 1
fi
CONF_CONTENT=$(cat "$CONF_DIR/ocs-live-test.conf")
if [[ "$CONF_CONTENT" == *"use_ocs_alias_blkdev="* ]]; then
  echo "FAIL: Expected use_ocs_alias_blkdev to be removed from mock config, but got: $CONF_CONTENT"
  exit 1
fi

# Test 9: Test sbin/clonezilla -ruoab reset option
echo "Testing sbin/clonezilla -ruoab reset option..."
# Back up real /etc/ocs/ocs-live.conf if it exists
if [ -f "/etc/ocs/ocs-live.conf" ]; then
  mv /etc/ocs/ocs-live.conf /etc/ocs/ocs-live.conf.bak
fi
mkdir -p /etc/ocs

# 1. Simulate state files and config
touch /tmp/use_ocs_alias_blkdev.state
echo 'use_ocs_alias_blkdev="yes"' > /etc/ocs/ocs-live.conf

# 2. Run reset with development copy scripts/sbin/ocs-functions sourced cleanly via a mock DRBL dir
MOCK_DRBL_DIR=$(mktemp -d)
mkdir -p "$MOCK_DRBL_DIR/sbin"
for f in /usr/share/drbl/sbin/*; do
  ln -sf "$f" "$MOCK_DRBL_DIR/sbin/$(basename "$f")"
done
ln -sf /root/clonezilla/scripts/sbin/ocs-functions "$MOCK_DRBL_DIR/sbin/ocs-functions"

DRBL_SCRIPT_PATH="$MOCK_DRBL_DIR" bash sbin/clonezilla -ruoab
rm -rf "$MOCK_DRBL_DIR"

# 3. Assert they are deleted / removed
if [ -f "/tmp/use_ocs_alias_blkdev.state" ]; then
  echo "FAIL: Expected /tmp/use_ocs_alias_blkdev.state to be deleted by clonezilla -ruoab"
  exit 1
fi
if grep -q "use_ocs_alias_blkdev" /etc/ocs/ocs-live.conf 2>/dev/null; then
  echo "FAIL: Expected use_ocs_alias_blkdev preference to be removed from ocs-live.conf"
  exit 1
fi

# Restore backup
rm -f /etc/ocs/ocs-live.conf
if [ -f "/etc/ocs/ocs-live.conf.bak" ]; then
  mv /etc/ocs/ocs-live.conf.bak /etc/ocs/ocs-live.conf
fi

# Test 10: Test get_mapped_kernel_or_ocs_blkname dynamic path stripping
echo "Testing get_mapped_kernel_or_ocs_blkname dynamic stripping..."
# Load the function
MAPPED_NAME_CODE=$(sed -n '/^get_mapped_kernel_or_ocs_blkname() {/,/^} # end of get_mapped_kernel_or_ocs_blkname/p' scripts/sbin/ocs-functions)
if [ -z "$MAPPED_NAME_CODE" ]; then
  echo "FAIL: Could not extract get_mapped_kernel_or_ocs_blkname"
  exit 1
fi
eval "$MAPPED_NAME_CODE"

# Create a mock mapping file
MOCK_MAPPED_DIR=$(mktemp -d)
mkdir -p "$MOCK_MAPPED_DIR/mock-alias-disks"
echo "ocs-sd01 sda mock_path" > "$MOCK_MAPPED_DIR/mock-alias-disks/dev-mapping.txt"

# Set the variable
ocs_dev_dir="$MOCK_MAPPED_DIR/mock-alias-disks"

# Resolve mapped name with a mocked path
res_val=$(get_mapped_kernel_or_ocs_blkname "/dev/mock-alias-disks/ocs-sd01")

if [[ "$res_val" != *"sda"* ]]; then
  echo "FAIL: Expected mapped kernel block name to contain sda, but got '$res_val'"
  exit 1
fi

rm -rf "$MOCK_MAPPED_DIR"

# Test 11: Test sorting of alias devices in checklist and menu modes
echo "Testing alias device sorting order in dialog..."
# Input kernel devices in non-alias order
mock_devs="nvme0n1 nvme0n2 nvme0n3 nvme0n4 nvme0n5 sda sdb"
MOCK_MAPPED_DIR=$(mktemp -d)
mkdir -p "$MOCK_MAPPED_DIR/ocs-blkdev"
cat << 'EOF' > "$MOCK_MAPPED_DIR/ocs-blkdev/dev-mapping.txt"
ocs-nd03 nvme0n1 pci-mock-7
ocs-nd02 nvme0n2 pci-mock-2
ocs-nd04 nvme0n3 pci-mock-8
ocs-nd05 nvme0n4 pci-mock-10
ocs-nd01 nvme0n5 pci-mock-1
ocs-sd01 sda     pci-mock-ata1
ocs-sd02 sdb     pci-mock-ata3
EOF

ocs_dev_dir="$MOCK_MAPPED_DIR/ocs-blkdev"
use_ocs_alias_blkdev="yes"
dev_chosen_def="off"
dev_items=""

for p in $mock_devs; do
  DEV_MODEL="dummy_model_for_$p"
  if [ "$use_ocs_alias_blkdev" = "yes" ]; then
    ocs_alias_name="$(get_mapped_kernel_or_ocs_blkname "$p" | xargs)"
    [ -n "$ocs_alias_name" ] && p="${ocs_alias_name}[$p]"
  fi
  if [ -n "$dev_chosen_def" ]; then
    dev_items+="$p $DEV_MODEL $dev_chosen_def"$'\n'
  else
    dev_items+="$p $DEV_MODEL"$'\n'
  fi
done

HARDDEVS="$(echo -n "$dev_items" | sed '/^$/d' | LC_ALL=C sort -V | tr '\n' ' ')"
first_item="$(echo $HARDDEVS | awk '{print $1}')"
second_item="$(echo $HARDDEVS | awk '{print $4}')"
third_item="$(echo $HARDDEVS | awk '{print $7}')"

if [ "$first_item" != "ocs-nd01[nvme0n5]" ]; then
  echo "FAIL: Expected first item to be ocs-nd01[nvme0n5], but got: $first_item"
  exit 1
fi

if [ "$second_item" != "ocs-nd02[nvme0n2]" ]; then
  echo "FAIL: Expected second item to be ocs-nd02[nvme0n2], but got: $second_item"
  exit 1
fi

if [ "$third_item" != "ocs-nd03[nvme0n1]" ]; then
  echo "FAIL: Expected third item to be ocs-nd03[nvme0n1], but got: $third_item"
  exit 1
fi

rm -rf "$MOCK_MAPPED_DIR"

echo "PASS: All ask_use_ocs_alias_blkdev and reset assertions passed successfully!"
exit 0
