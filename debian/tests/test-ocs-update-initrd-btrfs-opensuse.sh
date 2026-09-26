#!/bin/bash
# Test script for ocs-update-initrd with openSUSE Tumbleweed Btrfs subvolume layout.
# Tests that ocs-update-initrd correctly detects the Btrfs root/boot subvolume
# (@/.snapshots/1/snapshot or @), successfully chroots, and runs dracut.

set -e

echo "=== Running ocs-update-initrd openSUSE Tumbleweed Btrfs tests ==="

TEST_DIR="/tmp/test_ocs_update_initrd_opensuse"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

MOCK_NVME0N1P1="$TEST_DIR/nvme0n1p1"
MOCK_NVME0N1P2="$TEST_DIR/nvme0n1p2"

# Setup mock openSUSE Tumbleweed 20260923 filesystem structure
setup_opensuse_tumbleweed() {
  rm -rf "$MOCK_NVME0N1P1" "$MOCK_NVME0N1P2"
  mkdir -p "$MOCK_NVME0N1P1/EFI/opensuse"
  touch "$MOCK_NVME0N1P1/EFI/opensuse/grubx64.efi"

  # openSUSE Snapper layout in nvme0n1p2
  local snap_dir="$MOCK_NVME0N1P2/@/.snapshots/1/snapshot"
  mkdir -p "$snap_dir/boot"
  mkdir -p "$snap_dir/etc"
  mkdir -p "$snap_dir/usr/bin"
  mkdir -p "$snap_dir/bin"

  # Kernel and initrd in /boot
  touch "$snap_dir/boot/vmlinuz-6.11.0-default"
  touch "$snap_dir/boot/initrd-6.11.0-default"

  # OS release
  cat <<'EOF' > "$snap_dir/etc/os-release"
NAME="openSUSE Tumbleweed"
VERSION_ID="20260923"
PRETTY_NAME="openSUSE Tumbleweed"
ID="opensuse-tumbleweed"
EOF

  cat <<'EOF' > "$snap_dir/etc/fstab"
UUID=ccd5d734-bf49-4599-b8ae-1d5b125abb05 / btrfs defaults 0 0
UUID=9C89-A2D7 /boot/efi vfat defaults 0 0
EOF

  # Mock dracut executable
  cat <<'EOF' > "$snap_dir/usr/bin/dracut"
#!/bin/bash
# Mock dracut supporting --tmpdir option
echo "mock-dracut called with args: $*" >> /tmp/mock_dracut_execution.log
EOF
  chmod +x "$snap_dir/usr/bin/dracut"
}

# Run test wrapper
run_test_scenario() {
  local test_name="$1"
  local cmd_args="$2"

  echo "--- Test Scenario: $test_name ---"
  rm -f /tmp/mock_dracut_execution.log /tmp/mock_ocs_update_initrd.log

  # Create a runner script with mocked environment
  cat <<RUNNER_EOF > "$TEST_DIR/run_test.sh"
#!/bin/bash
set -e

# Mock mount
mount() {
  echo "mount \$*" >> /tmp/mock_ocs_update_initrd.log
  if [[ "\$1" == "--bind" ]]; then
    return 0
  fi
  local args=("\$@")
  local dest_pnt="\${args[-1]}"
  local src_dev="\${args[-2]}"
  mkdir -p "\$dest_pnt"
  if [[ "\$src_dev" == *nvme0n1p1 ]]; then
    cp -r "$MOCK_NVME0N1P1"/* "\$dest_pnt/" 2>/dev/null || true
  elif [[ "\$src_dev" == *nvme0n1p2 ]]; then
    cp -r "$MOCK_NVME0N1P2"/* "\$dest_pnt/" 2>/dev/null || true
  fi
}
export -f mount

unmount_wait_and_try() {
  echo "unmount_wait_and_try \$*" >> /tmp/mock_ocs_update_initrd.log
}
export -f unmount_wait_and_try

rmdir() {
  if [[ "\$1" == /tmp/root_reinst.* || "\$1" == /tmp/hd_* ]]; then
    rm -rf "\$1" 2>/dev/null || true
  else
    command rmdir "\$@" 2>/dev/null || true
  fi
}
export -f rmdir

chroot() {
  echo "chroot \$*" >> /tmp/mock_ocs_update_initrd.log
  local mnt="\$1"
  shift
  if [[ "\$1" == "ls" ]]; then
    [ -d "\$mnt" ] && return 0 || return 127
  elif [[ "\$1" == /initrd-sh-* ]]; then
    # In test, capture the generated dracut command
    local sh_path="\$mnt/\$1"
    local dracut_line
    dracut_line="\$(grep -E "^dracut" "\$sh_path" 2>/dev/null)"
    echo "mock-dracut called with args: \$dracut_line" >> /tmp/mock_dracut_execution.log
    return 0
  else
    return 0
  fi
}
export -f chroot

ocs-get-dev-info() {
  local dev="\$1"
  if [[ "\$dev" == *nvme0n1p1 ]]; then
    echo "filesystem vfat"
  elif [[ "\$dev" == *nvme0n1p2 ]]; then
    echo "filesystem btrfs"
  else
    echo "filesystem ext4"
  fi
}
export -f ocs-get-dev-info

# Run ocs-update-initrd
bash /root/clonezilla/sbin/ocs-update-initrd $cmd_args
RUNNER_EOF

  chmod +x "$TEST_DIR/run_test.sh"
  set +e
  bash "$TEST_DIR/run_test.sh"
  local rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $test_name failed with exit code $rc"
    cat /tmp/mock_ocs_update_initrd.log 2>/dev/null || true
    return 1
  fi

  # Verify dracut was actually executed
  if ! grep -q "mock-dracut called with args:" /tmp/mock_dracut_execution.log 2>/dev/null; then
    echo "FAIL: dracut was not executed in $test_name!"
    cat /tmp/mock_ocs_update_initrd.log 2>/dev/null || true
    return 1
  fi

  echo "PASS: $test_name"
  return 0
}

# Test 1: openSUSE Tumbleweed 20260923 with user's exact parameters
setup_opensuse_tumbleweed
run_test_scenario "openSUSE Tumbleweed with Snapper (@/.snapshots/1/snapshot)" '-p "nvme0n1p1 nvme0n1p2 " auto'

# Test 2: openSUSE / generic Btrfs with @ layout
rm -rf "$MOCK_NVME0N1P2"
mkdir -p "$MOCK_NVME0N1P2/@/boot" "$MOCK_NVME0N1P2/@/etc" "$MOCK_NVME0N1P2/@/usr/bin"
touch "$MOCK_NVME0N1P2/@/boot/vmlinuz-6.11.0-default"
touch "$MOCK_NVME0N1P2/@/boot/initrd-6.11.0-default"
touch "$MOCK_NVME0N1P2/@/etc/os-release"
cat <<'EOF' > "$MOCK_NVME0N1P2/@/usr/bin/dracut"
#!/bin/bash
echo "mock-dracut called with args: $*" >> /tmp/mock_dracut_execution.log
EOF
chmod +x "$MOCK_NVME0N1P2/@/usr/bin/dracut"
run_test_scenario "Btrfs with @ layout" '-p "nvme0n1p1 nvme0n1p2 " auto'

# Test 3: Explicit partition given instead of auto
setup_opensuse_tumbleweed
run_test_scenario "Explicit Btrfs partition (/dev/nvme0n1p2)" '/dev/nvme0n1p2'

# Clean up
rm -rf "$TEST_DIR" /tmp/mock_dracut_execution.log /tmp/mock_ocs_update_initrd.log

echo "=== All openSUSE Tumbleweed Btrfs tests passed successfully ==="
exit 0
