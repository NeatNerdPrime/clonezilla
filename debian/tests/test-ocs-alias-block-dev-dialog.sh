#!/bin/bash
# Standalone test for ocs-functions ask_use_ocs_alias_blkdev function.

set -e

echo "=== Running ask_use_ocs_alias_blkdev Dialog Tests ==="

# Clean up any potential state file from previous system/interactive runs
rm -f /tmp/use_ocs_alias_blkdev.state

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

# Test 3: Prompting and selecting -uoab
echo "Testing selection of -uoab..."
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
trap "rm -rf $CONF_DIR; rm -f /tmp/use_ocs_alias_blkdev.state" EXIT
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

# Verify state file was created and contains "yes"
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

# Test 5: Prompting and selecting " " (space)
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

# Test 6: Skip when already configured in ocs-live.conf
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

echo "PASS: All ask_use_ocs_alias_blkdev assertions passed successfully!"
exit 0
