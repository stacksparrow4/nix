#!/usr/bin/env bash
#
# snapshot.sh - Manage snapshots of libvirt VMs.
#
# Two logical sets of VMs are supported:
#   - windows : the standalone Windows machine ("windows")
#   - ad      : the Active Directory lab ("ad-dc", "ad-server", "ad-client")
#
# The "ad" set is treated as a single logical unit: creating or restoring a
# snapshot acts on all 3 instances at once so they stay in sync.
#
# Snapshots copy the relevant files out of /var/lib/libvirt/ (via sudo) and
# store them under ~/.local/libvirt-snapshots.

set -euo pipefail

# --- Configuration ---------------------------------------------------------

LIBVIRT_DIR="/var/lib/libvirt"
IMAGES_DIR="${LIBVIRT_DIR}/images"
NVRAM_DIR="${LIBVIRT_DIR}/qemu/nvram"
SNAPSHOT_ROOT="${HOME}/.local/libvirt-snapshots"

# VMs belonging to each logical set.
WINDOWS_VMS=(windows)
AD_VMS=(ad-dc ad-server ad-client)

# --- Helpers ---------------------------------------------------------------

die() {
	echo "error: $*" >&2
	exit 1
}

usage() {
	cat >&2 <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  list [set]                    List snapshots (optionally for a single set)
  create <set> <snapshot-name>  Create a snapshot of a set
  restore <set> <snapshot-name> Restore a snapshot of a set

Sets:
  windows   The standalone Windows machine
  ad        The 3 AD machines (ad-dc, ad-server, ad-client) as one unit

Examples:
  $(basename "$0") list
  $(basename "$0") create ad clean-install
  $(basename "$0") restore windows before-update
EOF
	exit 1
}

# Echo the VM names for a given set.
vms_for_set() {
	case "$1" in
	windows) echo "${WINDOWS_VMS[@]}" ;;
	ad) echo "${AD_VMS[@]}" ;;
	*) die "unknown set '$1' (expected 'windows' or 'ad')" ;;
	esac
}

# Ensure a VM is not running before snapshotting/restoring its disk.
assert_not_running() {
	local vm="$1"
	if virsh -c qemu:///system list --name --state-running 2>/dev/null | grep -qx "$vm"; then
		die "VM '$vm' is running; shut it down before snapshotting/restoring"
	fi
}

# --- Commands --------------------------------------------------------------

cmd_list() {
	local set="${1:-}"
	local sets

	if [[ -n "$set" ]]; then
		# Validate the set name.
		vms_for_set "$set" >/dev/null
		sets=("$set")
	else
		sets=(windows ad)
	fi

	for s in "${sets[@]}"; do
		echo "Snapshots for set '$s':"
		local dir="${SNAPSHOT_ROOT}/${s}"
		local found=0
		if [[ -d "$dir" ]]; then
			for snap in "$dir"/*/; do
				[[ -d "$snap" ]] || continue
				printf '  - %s\n' "$(basename "$snap")"
				found=1
			done
		fi
		[[ "$found" -eq 1 ]] || echo "  (none)"
	done
}

cmd_create() {
	local set="${1:-}"
	local name="${2:-}"
	[[ -n "$set" && -n "$name" ]] || usage

	local vms
	read -r -a vms <<<"$(vms_for_set "$set")"

	local dest="${SNAPSHOT_ROOT}/${set}/${name}"
	[[ -e "$dest" ]] && die "snapshot '$name' already exists for set '$set'"

	# Make sure none of the VMs are running.
	for vm in "${vms[@]}"; do
		assert_not_running "$vm"
	done

	echo "Creating snapshot '$name' for set '$set' (${vms[*]})..."
	mkdir -p "$dest"

	for vm in "${vms[@]}"; do
		local disk="${IMAGES_DIR}/${vm}.qcow2"
		local nvram="${NVRAM_DIR}/${vm}.nvram"

		[[ -e "$disk" ]] || die "disk image not found: $disk"

		echo "  - copying disk for '$vm'"
		sudo cp --reflink=auto "$disk" "${dest}/${vm}.qcow2"

		if sudo test -e "$nvram"; then
			echo "  - copying nvram for '$vm'"
			sudo cp "$nvram" "${dest}/${vm}.nvram"
		fi
	done

	# Make the copied files owned by the current user.
	sudo chown -R "$(id -u):$(id -g)" "$dest"

	echo "Done."
}

cmd_restore() {
	local set="${1:-}"
	local name="${2:-}"
	[[ -n "$set" && -n "$name" ]] || usage

	local vms
	read -r -a vms <<<"$(vms_for_set "$set")"

	local src="${SNAPSHOT_ROOT}/${set}/${name}"
	[[ -d "$src" ]] || die "snapshot '$name' not found for set '$set'"

	# Make sure none of the VMs are running.
	for vm in "${vms[@]}"; do
		assert_not_running "$vm"
	done

	echo "Restoring snapshot '$name' for set '$set' (${vms[*]})..."

	for vm in "${vms[@]}"; do
		local disk_snap="${src}/${vm}.qcow2"
		local nvram_snap="${src}/${vm}.nvram"

		[[ -e "$disk_snap" ]] || die "disk snapshot missing for '$vm': $disk_snap"

		echo "  - restoring disk for '$vm'"
		sudo cp --reflink=auto "$disk_snap" "${IMAGES_DIR}/${vm}.qcow2"

		if [[ -e "$nvram_snap" ]]; then
			echo "  - restoring nvram for '$vm'"
			sudo mkdir -p "$NVRAM_DIR"
			sudo cp "$nvram_snap" "${NVRAM_DIR}/${vm}.nvram"
		fi
	done

	echo "Done."
}

# --- Entry point -----------------------------------------------------------

main() {
	local cmd="${1:-}"
	[[ -n "$cmd" ]] || usage
	shift

	case "$cmd" in
	list) cmd_list "$@" ;;
	create) cmd_create "$@" ;;
	restore) cmd_restore "$@" ;;
	*) usage ;;
	esac
}

main "$@"
