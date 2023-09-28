#!/bin/bash
# Function to handle btrfs send errors
handle_error() {
    local exit_code="$?"
    local error_message="$1"
    echo "Error ($exit_code): $error_message" >&2
    exit "$exit_code"
}

# Trap the error and call the handle_error function with the error message
#trap 'handle_error "An error occurred while running btrfs send."' ERR

# Dependency: btrfs
BTRFS=${BTRFS:-/sbin/btrfs}
if ! type $BTRFS >/dev/null 2>&1; then
    BTRFS=btrfs
    if ! type $BTRFS >/dev/null 2>&1; then
        echo "Dependency not found: btrfs" >&2
        exit 1
    fi
fi

# Dependency: stat
STAT=stat
if ! type $STAT >/dev/null 2>&1; then
    STAT=/usr/bin/stat
    if [ ! -x "$STAT" ]; then
        echo "Dependency not found: stat" >&2
        exit 1
    fi
fi

# Dependency: ping
PING=ping
if ! type $PING >/dev/null 2>&1; then
    PING=/bin/ping
    if [ ! -x "$PING" ]; then
        echo "Dependency not found: ping" >&2
        exit 1
    fi
fi
# Dependency: SSH
SSH_CMD=${SSH_CMD:-/usr/bin/ssh}
if ! type $SSH_CMD >/dev/null 2>&1; then
    SSH_CMD=ssh
    if ! type $SSH_CMD >/dev/null 2>&1; then
        echo "Dependency not found: SSH" >&2
        exit 1
    fi
fi
# Dependency: virsh
VIRSH_CMD=${VIRSH_CMD:-/usr/bin/virsh}
if ! type "$VIRSH_CMD" >/dev/null 2>&1; then
    VIRSH_CMD=virsh
    if ! type "$VIRSH_CMD" >/dev/null 2>&1; then
        echo "Dependency not found: virsh" >&2
        exit 1
    fi
fi
#======
# USAGE
#======
#/home/user/bash/btrfs-send-clean.sh /mnt/btrfs/snapshot/base/binpkgs_2023-09-08_13:57:08 /var/db/repos/gentoo /mnt/btrfs/snapshot/timeline portage 3
# Check if the script is called with the correct number of arguments.
if [ $# -lt 4 ]; then
    echo "Usage: $0 <base> <subvol> <path> <prefix> <days_to_retain>"
    exit 1
fi

# Check if virsh is installed
if ! command -v virsh &> /dev/null; then
    echo "Error: virsh command not found. Make sure libvirt is installed."
    exit 1
fi

# List all running virtual machines and initiate a shutdown
echo "Shutting down running Virtual Machines:"
for vm_name in $(virsh list --name --state-running); do
    virsh shutdown "$vm_name"
done

# Wait for up to one minute for graceful shutdown
echo "Waiting for virtual machines to shut down gracefully..."
for i in {1..60}; do
    all_shutdown=true
    for vm_name in $(virsh list --name --state-running); do
        all_shutdown=false
        break
    done
    if [ "$all_shutdown" = true ]; then
        break
    fi
    sleep 1
done

# Forcefully power off any remaining running virtual machines
echo "Forcing power off of any remaining running Virtual Machines:"
for vm_name in $(virsh list --name --state-running); do
    virsh destroy "$vm_name"
done

sleep 5;

# Get the path, prefix, and days to retain from the command-line arguments.
base="$1"
subvol="$2"
path="$3"
prefix="$4"
days_to_retain="$5"
store="store"

# Check if the specified path exists.
if [ ! -d "$path" ]; then
    echo "Error: The specified path '$path' does not exist." >&2
    exit 1
fi

# Get the current date in the format YYYY_MM_DD.
current_date=$(date +%Y_%m_%d)

# Create the folder name by combining the prefix and current date.
folder_name="${prefix}_${current_date}"

# Check if the folder already exists for the current day.
if [ -d "$path/$folder_name" ]; then
    echo "Snapshot '$path/$folder_name' already exists for today. No new snapshot created."
else
    # Create the folder if it doesn't exist.
    /sbin/btrfs subvolume snapshot $subvol "$path/$folder_name"

    newsnap="$path/$folder_name"
    # Check exists: $newsnap
    if [ -z "$newsnap" ]; then
        echo "Snapshot $newsnap failed"
        exit 1
    fi
    newsnap_inum=$($STAT --printf="%i" "$newsnap")
    if [[ $? -ne 0 || -z "$newsnap_inum" ]]; then
        echo "Getting newsnap info failed!"
        exit 1
    fi
    if [ $newsnap_inum -ne 256 ]; then
        echo "Not a BTRFS filesystem: $newsnap"
        exit 1
    fi

    echo "Created snapshot: $path/$folder_name"

    # Switch the new snapshot to read-only for sending
    /sbin/btrfs property set -ts $newsnap ro true

    yesterday_date=$(date -d "yesterday" +%Y_%m_%d)

    # Check if a folder with yesterday's date exists on the remote server.
    ssh_output=$(ssh $store "[ -d \"$path/${prefix}_${yesterday_date}\" ] && echo 1 || echo 0")

    # Select which base subvolume to send the difference from
    if [ -d "$path/${prefix}_${yesterday_date}" ] && [ "$ssh_output" -eq 1 ]; then

        # Check if the subvolume is read-only
        is_readonly=$(/sbin/btrfs property get "$base" ro | awk '{print $NF}')

        # Check if the subvolume is read-only on the localhost
        if [ "$is_readonly" == "ro=true" ]; then
            base="$path/${prefix}_${yesterday_date}"
            echo "The Btrfs subvolume at $base is read-only."
        else
            # Use the original base value if no yesterday's snapshot is found.
            echo "The Btrfs subvolume at $base is not read-only."
        fi
    else
        # Use the original base value if no yesterday's snapshot is found.
	echo "Found no yesturday snapshot."
    fi

    echo "Using difference from subvolume: $base"

    # Check if the subvolume is read-only
    is_readonly=$(/sbin/btrfs property get "$base" ro | awk '{print $NF}')

    # Check if the subvolume is read-only on the localhost
    if [ "$is_readonly" == "ro=true" ]; then
        echo "The Btrfs subvolume at $base is read-only."
    else
        echo "The Btrfs subvolume at $base is not read-only." >&2
        exit 1
    fi

    # Check if the remote Btrfs subvolume is read-only
    is_readonly_store=$(ssh $store "/sbin/btrfs property get \"$base\" ro" | awk '{print $NF}')

    # Check if the subvolume is read-only on the store host
    if [ "$is_readonly_store" == "ro=true" ]; then
        echo "The Btrfs subvolume on store at $base is read-only."
    else
        echo "The Btrfs subvolume on store at $base is not read-only."
        exit 1
    fi

    trap 'handle_error "An error occurred while running btrfs send."' ERR

    # Send the difference
    /sbin/btrfs send -q -p $base $newsnap | /usr/bin/ssh $store "btrfs -q receive /mnt/btrfs/snapshot/timeline"

    # Disable the error trap to continue scripting
    trap - ERR

    # Calculate the cutoff date for folders to be deleted.
    cutoff_date=$(date -d "$days_to_retain days ago" +%Y_%m_%d)

    # Find and delete folders older than the cutoff date.
    /usr/bin/find "$path" -type d -name "${prefix}_*" -printf "%f\n" | while read -r folder; do
        folder_date="${folder#${prefix}_}"
        if [[ "$folder_date" < "$cutoff_date" ]]; then
            /sbin/btrfs subvolume delete "$path/$folder"
            echo "Deleted snapshot: $path/$folder"
        fi
    done
    echo "Deleted snapshots older than $days_to_retain days."

    # Specify the remote path to search for folders
    remote_path=$path

    # Specify the prefix of the folders you want to delete
    folder_prefix=$prefix

    # List folders that match the prefix and are older than the cutoff date on the remote host
    ssh $store "/usr/bin/find \"$remote_path\" -type d -name \"${folder_prefix}_*\" -printf \"%f\n\"" | while read -r folder; do
        folder_date="${folder#${folder_prefix}_}"
        if [[ "$folder_date" < "$cutoff_date" ]]; then
            # Delete the folder on the remote host
            ssh $store "/sbin/btrfs subvolume delete \"$remote_path/$folder\""
            echo "Deleted subvolume on store: $remote_path/$folder"
        fi
    done
fi


exit

