#!/bin/bash
# Installs gentoo to /dev/sda1
#!/bin/bash

GentooGetStage3() {
    echo "Entering Gentoo Get Stage 3 Function." &>2

    # Local directory to save the tarball
    DEST_DIR="/mnt/gentoo/rootfs"
    echo "DEST_DIR: $DEST_DIR" &>2

    # URL for the Gentoo stage3 tarballs
    BASE_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/"
    echo "BASE_URL: $BASE_URL" &>2

    # Get the latest stage3 tarball URL
    LATEST_URL=$(curl -s "https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/" | grep stage3-amd64-desktop-openrc | grep -oP 'href="[^"]+"' | cut -d'"' -f2 | sort | head -n 1)

    # Check if we found a stage 3 tarball
    echo "LATEST_URL: $LATEST_URL" &>2
    if [ -z "$LATEST_URL" ]; then
        echo "Error: Could not find a valid stage3 tarball URL." &>2
        exit 1
    fi

    FULL_STAGE3_URL="$BASE_URL$LATEST_URL"
    FULL_SHA256_URL="$FULL_STAGE3_URL.sha256"

    # Define the filename based on the URL
    FILE_NAME=$(basename "$FULL_STAGE3_URL")

    # Check if the file already exists in the destination directory
    if [ ! -f "$DEST_DIR/$FILE_NAME" ]; then
        # File does not exist, so download it
        echo "Downloading $FILE_NAME..." &>2
        wget -P "$DEST_DIR" "$FULL_STAGE3_URL" &>2
        if [ $? -eq 0 ]; then
            echo "$FILE_NAME downloaded successfully." &>2
        else
            echo "Failed to download $FILE_NAME." &>2
            exit 1
        fi
    else
        # File already exists
        echo "$FILE_NAME already exists in $DEST_DIR." &>2
    fi

    # Define the filename based on the URL
    FILE_NAME=$(basename "$FULL_SHA256_URL")

    # Check if the file already exists in the destination directory
    if [ ! -f "$DEST_DIR/$FILE_NAME" ]; then
        # File does not exist, so download it
        echo "Downloading $FILE_NAME..." &>2
        wget -P "$DEST_DIR" "$FULL_SHA256_URL" &>2
        if [ $? -eq 0 ]; then
            echo "$FILE_NAME downloaded successfully." &>2
        else
            echo "Failed to download $FILE_NAME." &>2
            exit 1
        fi
    else
        # File already exists
        echo "$FILE_NAME already exists in $DEST_DIR." &>2
    fi

    # Calculate the SHA256 checksum of the downloaded stage3 tarball
    DOWNLOADED_SHA256=$(sha256sum "$DEST_DIR/$(basename "$LATEST_URL")" | cut -d' ' -f1)
    echo "DOWNLOADED_SHA256 = $DOWNLOADED_SHA256" &>2

    # Get the expected SHA256 checksum from the .sha256 file
    EXPECTED_SHA256=$(awk '/SHA256 HASH/{getline; split($0, a, " "); print a[1]}' "$DEST_DIR/$(basename "$LATEST_URL").sha256")
    echo "EXPECTED_SHA256 = $EXPECTED_SHA256" &>2

    # Compare the sha256 ckecksum
    if [ "$DOWNLOADED_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "Error: SHA256 checksum does not match. Downloaded file may be corrupted." &>2
        exit 1
    else
        echo "Download and checksum verification complete." &>2
    fi

    # Return the LATEST_URL
    echo "$LATEST_URL"
}

generate_make_conf() {
    # Define the configuration content
    local make_conf_content=$(cat <<EOL
# These settings were set by the gentoo-installer script that automatically
# built this stage.
# Please consult /usr/share/portage/config/make.conf.example for a more
# detailed example.
COMMON_FLAGS="-O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# NOTE: This stage was built with the bindist Use flag enabled
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C

# Manual Addition
LINGUAS="en en_US"
CHOST="x86_64-pc-linux-gnu"
USE="-handbook -doc python_targets_python3_10 -python_targets_python3_11 -systemd -pulseaudio mmx sse sse2"
MAKEOPTS="-j5"
#FEATURES="buildpkg"
#FEATURES="buildpkg -collision-protect -protect-owned"
#FEATURES="buildpkg userfetch getbinpkg -collision-protect -protect-owned"
FEATURES="buildpkg userfetch getbinpkg -collision-protect -protect-owned"
#Stripping features
#FEATURES="buildpkg userfetch getbinpkg -collision-protect -protect-owned nodoc noman noinfo unmerge-backup"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --quiet-build=y --binpkg-respect-use=n --binpkg-changed-deps=n"
#
PORTAGE_BINHOST="http://127.0.0.1/packages" #binary packages
#To find the fastest gentoo mirrors use - mirrorselect -s3 -b10 -D
GENTOO_MIRRORS="http://tux.rainside.sk/gentoo/ http://gentoo.mirror.root.lu/ http://mirror.lzu.edu.cn/gentoo"
#
ACCEPT_LICENSE="*"
#ACCEPT_LICENSE="-* @FREE @BINARY-REDISTRIBUTABLE"
#
#VIDEO_CARDS="intel i915 i965 amdgpu radeon r128 radeonsi cirrus nvidia qxl vesa apm ast chips dummy epson fbdev geode glint i128 i740 mach64 mga modesettin$
#INPUT_DEVICES="evdev synaptics joystick"
#
#QEMU_SOFTMMU_TARGETS="alpha aarch64 arm i386 m68k mips mips64 mips64el mipsel ppc ppc64 riscv32 riscv64 s390x sh4 sh4eb sparc sparc64 x86_64"
#QEMU_USER_TARGETS="alpha aarch64 arm armeb i386 m68k mips mipsel ppc ppc64 ppc64abi32 riscv32 riscv64 s390x sh4 sh4eb sparc sparc32plus"
#QEMU_SOFTMMU_TARGETS="arm i386 x86_64"
#QEMU_USER_TARGETS="arm i386 x86_64"
#
EOL
    )
    # Local directory to save the tarball
    DEST_DIR="/mnt/gentoo/rootfs"

    # Specify the path for the make.conf file
    local make_conf_file="$DEST_DIR/etc/portage/make.conf" # Update this path as needed

    # Check if the file already exists and prompt for overwrite
    if [ -e "$make_conf_file" ]; then
        read -p "File $make_conf_file already exists. Overwrite? (y/n): " overwrite
        if [ "$overwrite" != "y" ]; then
            echo "File not overwritten. Exiting."
            return 1
        fi
    fi

    # Write the configuration to the make.conf file
    echo "$make_conf_content" > "$make_conf_file"
    echo "make.conf file created at $make_conf_file"
}

# Call the function to generate the make.conf file
#generate_make_conf

generate_fstab() {
    # Get UUIDs for /dev/sda1, /dev/sda2, and /dev/sda3
    efi_uuid=$(blkid -s UUID -o value /dev/sda1)
    boot_uuid=$(blkid -s UUID -o value /dev/sda2)
    rootfs_uuid=$(blkid -s UUID -o value /dev/sda3)

    local fstab_content=$(cat <<EOL
# Automatic from Gentoo Installer Script
UUID=$efi_uuid /efi                         vfat    noatime                                                         0 0
UUID=$boot_uuid /boot                       ext2    noatime                                                         1 2
UUID=$rootfs_uuid /mnt/btrfs                btrfs   defaults,noatime,compress=lzo,autodefrag                        0 0
UUID=$rootfs_uuid /                         btrfs   defaults,noatime,compress=lzo,autodefrag,subvol=@rootfs         0 1
shm /dev/shm                                tmpfs   nodev,nosuid,noexec                                             0 0
# Example - Additional Subvolumes
#UUID=$rootfs_uuid /home                   btrfs   defaults,noatime,compress=lzo,autodefrag,subvol=@home           0 0
#UUID=$rootfs_uuid /var/cache/distfiles    btrfs   defaults,noatime,autodefrag,subvol=@distfiles                   0 0
#UUID=$rootfs_uuid /var/cache/binpkgs      btrfs   defaults,noatime,autodefrag,subvol=@binpkgs                     0 0
#UUID=$rootfs_uuid /var/db/repos/gentoo    btrfs   defaults,noatime,compress=lzo,autodefrag,subvol=@portage        0 0
# Example - USB Stick Install
#LABEL=GENTOO_USB_BOOT /boot                ext2    noatime                                                         1 2
#LABEL=GENTOO_USB_ROOT /                    ext4    noatime                                                         0 1
#LABEL=GENTOO_USB_SWAP none                 swap    sw                                                              0 0
EOL
    )

    local fstab_file="/mnt/gentoo/rootfs/etc/fstab" # Update this path as needed

    # Check if the file already exists and prompt for overwrite
    if [ -e "$fstab_file" ]; then
        read -p "File $fstab_file already exists. Overwrite? (y/n): " overwrite
        if [ "$overwrite" != "y" ]; then
            echo "File not overwritten. Exiting."
            return 1
        fi
    fi

    # Write the fstab configuration to the file
    echo "$fstab_content" > "$fstab_file"
    echo "fstab file created at $fstab_file"
}

# Call the function to generate the fstab file
#generate_fstab


# Function to calculate the SHA-256 checksum
calculate_sha256() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

wipe_disk() {
    # Define disk device
    DISK="/dev/sda"

    # Ask the user what to wipe
    echo "Select what to wipe on $DISK:"
    echo "1. Entire Disk"
    echo "2. First 3GB"
    echo "3. Don't do it."
    read -p "Enter your choice (1/2/3): " choice

    case "$choice" in
        1)
            # Confirm the action
            read -p "Are you sure you want to wipe the entire disk $DISK? This will result in data loss. (y/n) " confirm
            if [ "$confirm" = "y" ]; then
                # Wipe the entire disk with zeros
                echo "Filling the entire disk $DISK with zeros."
                dd if=/dev/zero of="$DISK" bs=1M status=progress
                echo "The entire disk $DISK has been wiped with zeros."
            else
                echo "Wiping canceled. No data loss occurred."
            fi
            ;;
        2)
            # Confirm the action
            read -p "Are you sure you want to wipe the first 3GB of disk $DISK? This will result in data loss. (y/n) " confirm
            if [ "$confirm" = "y" ]; then
                # Wipe the first 3GB of the disk with zeros
                echo "Filling the first 3GB of disk $DISK with zeros."
                dd if=/dev/zero of="$DISK" bs=1M count=3072 status=progress
                echo "The first 3GB of $DISK has been wiped with zeros."
            else
                echo "Wiping canceled. No data loss occurred."
            fi
            ;;
        3)
            # Exit the script
            echo "Skipping dd."
            ;;
        *)
            echo "Invalid choice. No wiping performed."
            ;;
    esac
}


# Function to partition the disk
partition_disk() {
    # Define disk device
    DISK="/dev/sda"

    # Ensure the disk is not mounted
    umount -l "$DISK"* 2>/dev/null

    wipe_disk

#    partprobe $DISK

#    sync $DISK

    # Use parted to create partitions
#not this one msdos works well    parted "$DISK" mklabel gpt
    parted "$DISK" mklabel msdos

    # Create the EFI System Partition
    parted -a optimal "$DISK" mkpart primary fat32 1MiB 2GiB
    parted "$DISK" set 1 esp on

    # Create the Linux filesystem partitions
    parted -a optimal "$DISK" mkpart primary ext2 2GiB 4GiB
    parted "$DISK" set 2 boot on

    # Root partition (Btrfs)
    parted -a optimal "$DISK" mkpart primary btrfs 4GiB 100%

    # Print partition information
    parted "$DISK" print
}

# Function to format partitions
format_partitions() {
    # Add commands here to format partitions
    DISK="/dev/sda"

    # Ensure the disk is not mounted
    umount -l "$DISK"* 2>/dev/null

    echo "Formatting partitions..."

    # Format EFI partition as FAT32
    echo "Formatting EFI partition as FAT32..."
    mkfs.fat -F32 "$DISK"1
    echo "EFI partition formatted as FAT32."

    # Format boot partition as ext2
    echo "Formatting boot partition as ext2..."
    mkfs.ext2 "$DISK"2
    echo "Boot partition formatted as ext2."

    # Format root partition as Btrfs
    echo "Formatting root partition as Btrfs..."
    mkfs.btrfs "$DISK"3 -f
    echo "Root partition formatted as Btrfs."

#    grub-install "$DISK"

    echo "Partitions formatted successfully."
}

# Function to mount partitions
mount_partitions() {
    # Add commands here to mount partitions

    # Define the disk and partition number
    DISK="/dev/sda"  # Replace X with the appropriate letter for your disk (e.g., "a" for /dev/sda)
    PARTITION_NUM=3

    # Define the mount point
    MOUNT_POINT="/mnt/gentoo"

    # Ensure the disk is not mounted
    umount -l "$DISK"* 2>/dev/null

    # Mount the Btrfs partition
    mkdir -p "${MOUNT_POINT}"
    mount "${DISK}${PARTITION_NUM}" "${MOUNT_POINT}"

    # Confirm that the partition is mounted
    if mountpoint -q "${MOUNT_POINT}"; then
      echo "Partition is mounted at ${MOUNT_POINT}"

      # Create a Btrfs subvolume named @rootfs
      btrfs subvolume create "${MOUNT_POINT}/@rootfs"

      # Mount the subvolume
      SUBVOLUME_MOUNT_POINT="${MOUNT_POINT}/rootfs"
      mkdir -p "${SUBVOLUME_MOUNT_POINT}"
      mount -o subvol=@rootfs "${DISK}${PARTITION_NUM}" "${SUBVOLUME_MOUNT_POINT}"

      # Confirm that the subvolume is mounted
      if mountpoint -q "${SUBVOLUME_MOUNT_POINT}"; then
        echo "Subvolume is mounted at ${SUBVOLUME_MOUNT_POINT}"

        # Create directories if they don't exist within the subvolume
        mkdir -p "${SUBVOLUME_MOUNT_POINT}/boot"
        mkdir -p "${SUBVOLUME_MOUNT_POINT}/efi"

        # Mount /dev/sda1 to /mnt/gentoo/@rootfs/efi
        mount "/dev/sda1" "${SUBVOLUME_MOUNT_POINT}/efi"

        # Mount /dev/sda2 to /mnt/gentoo/@rootfs/boot
        mount "/dev/sda2" "${SUBVOLUME_MOUNT_POINT}/boot"

        echo "/dev/sda1 is mounted to ${SUBVOLUME_MOUNT_POINT}/efi"
        echo "/dev/sda2 is mounted to ${SUBVOLUME_MOUNT_POINT}/boot"
      else
        echo "Subvolume mount failed"
      fi

    else
      echo "Partition mount failed"
    fi
}

# Function to configure network
configure_network() {
#    echo "# Add commands here to configure network settings"
    nmtui
}

generate_packageuse() {
    # Local directory to save the tarball
    DEST_DIR="/mnt/gentoo/rootfs"

    while true; do
        # Prompt the user for input
        read -p "Generate Package Use? (yes/no): " user_input

        # Check if the user_input is "yes"
        if [ "$user_input" == "yes" ]; then
            echo "Generating Package Use..."
            mkdir -p /mnt/gentoo/rootfs/etc/portage/package.use
            cp $1 $DEST_DIR/etc/portage/package.use/custom
            echo "Package Use generated."
            break
        elif [ "$user_input" == "no" ]; then
            echo "User chose not to generate Package Use. Exiting without performing the action."
            break
        else
            echo "Invalid input. Please enter 'yes' or 'no'."
        fi
    done
}

# Usage:
# append_or_clear_file "file_path" "line_to_add" "clear"   # Clear and append
# append_or_clear_file "file_path" "line_to_add"           # Just append

# Example: Clear the file and add the line
#append_or_clear_file "$file_path" "$line_to_add" "clear"

# Function to append a line to a file
append_or_clear_file() {
    local file="$1"
    local line="$2"
    local clear_file="$3"

    if [ "$clear_file" = "clear" ]; then
        # Create the file if it doesn't exist and clear its contents
        > "$file"
    fi

    # Append the line to the file
    echo "$line" >> "$file"
}

generate_packageset() {
    # Local directory to save the tarball
    DEST_DIR="/mnt/gentoo/rootfs"

    while true; do
        # Prompt the user for input
        read -p "Generate Package Set? (yes/no): " user_input

        # Check if the user_input is "yes"
        if [ "$user_input" == "yes" ]; then
            echo "Generating Package Set..."
            mkdir -p /mnt/gentoo/rootfs/etc/portage/sets
            cp $1 $DEST_DIR/etc/portage/sets
            echo "Package Set generated."

            set_name=$(basename "$1")

            # Define the line to add
            line_to_add="@$set_name"

            # Specify the path to the file
            file_path="$DEST_DIR/var/lib/portage/world_sets"

            # Usage:
            # append_or_clear_file "file_path" "line_to_add" "clear"   # Clear and append
            # append_or_clear_file "file_path" "line_to_add"           # Just append

            # Example: Clear the file and add the line
            append_or_clear_file "$file_path" "$line_to_add" "clear"

            echo "Added '$line_to_add' to '$file_path'."



            break
        elif [ "$user_input" == "no" ]; then
            echo "User chose not to generate Package Set. Exiting without performing the action."
            break
        else
            echo "Invalid input. Please enter 'yes' or 'no'."
        fi
    done
}

# Define a function for setting up and entering the Gentoo chroot environment
setup_gentoo_chroot() {
    local DEST_DIR="/mnt/gentoo/rootfs"

    # Create necessary directories for chroot
    mkdir -p "$DEST_DIR/proc"
    mkdir -p "$DEST_DIR/dev"
    mkdir -p "$DEST_DIR/sys"

    # Mount necessary filesystems for chroot
    mount --types proc /proc "$DEST_DIR/proc"
    mount --rbind /sys "$DEST_DIR/sys"
    mount --make-rslave "$DEST_DIR/sys"
    mount --rbind /dev "$DEST_DIR/dev"
    mount --make-rslave "$DEST_DIR/dev"
    cp /etc/resolv.conf "$DEST_DIR/etc"

    # Display message before entering the chroot
    echo "Preparing to chroot into the Gentoo environment..."

    # Chroot into the Gentoo environment
    chroot "$DEST_DIR/" /bin/bash <<EOF

    # Now, we are inside the chroot environment. You can execute commands here.

    # Example command inside the chroot environment:
    echo "Hello from inside the chroot environment!"

    # Set the timezone (replace 'Canada/Pacific' with your desired timezone)
    ln -sf /usr/share/zoneinfo/Canada/Pacific /etc/localtime

    # You may also want to update the system clock if necessary
    hwclock --systohc

    # Set a repos to pull portage tree
    mkdir -p /etc/portage/repos.conf
    cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf


#    emerge --sync

#    emerge --update --deep --newuse @world
    /bin/sh /usr/local/bin/gentoo-system-update.sh



    emerge gentoolkit
    emerge linux-firmware

#    # Configure other system settings as needed
#    emerge mirrorselect
#    mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
    useradd -m -G wheel,audio,users,kvm user
    echo "root:I love linux :-)" | chpasswd
    echo "user:I love linux :-)" | chpasswd

    # Emerge in a simple desktop

    mkdir -p /boot/grub
    emerge gentoo-kernel
    emerge gentoo-sources
# we better be in a chroot and all disk better be setup correct here
# ask user the confirm what we are doing
    emerge parted
    emerge grub
#    parted /dev/sda set 2 boot on done at partitioning
    grub-install /dev/sda
    grub-mkconfig -o /boot/grub/grub.cfg
    grub-install --target=x86_64-efi --efi-directory=/efi --removable
    # Generate the BOOTX64.EFI file
    grub-mkimage -o /efi/EFI/BOOT/BOOTX64.EFI -O x86_64-efi -p /efi/EFI/BOOT/ part_gpt part_msdos lvm mdraid09 mdraid1x normal boot configfile linux multiboot chain efifwsetup efi_gop efi_uga g>

    # Install GRUB to the EFI System Partition (ESP)
    #grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=gentoo

    # Generate the GRUB configuration file
    #grub-mkconfig -o /efi/EFI/BOOT/grub/grub.cfg

    grub-mkconfig -o /boot/grub/grub.cfg
    grub-install --target=x86_64-efi --efi-directory=/efi --removable

    echo "GRUB has been installed to /efi/EFI/BOOT/BOOTX64.EFI and configured."
    echo "You can edit the GRUB configuration file at /efi/EFI/BOOT/grub/grub.cfg."

#    Ask user if they want to reboot or manual install things in a screen before reboot
#    shutdown -r now
#
EOF

    # Display message after exiting the chroot
    echo "Exited the Gentoo chroot environment."

    # You are now back to the original environment outside of the chroot.
    # Any further commands here will not affect the chrooted system.
}

# Function to configure bootloader
configure_bootloader() {
    echo "# Add commands here to configure the bootloader"
}

#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================
#======================================================================================================================================================

# Define default values for options
stage3_file=""
packageuse_file=""
packageset_file=""
binpkgs_host="http://0001.ca/binpkgs"
repo_url="http://tux.rainside.sk/gentoo/"
verbose=false
DEST_DIR="/mnt/gentoo/rootfs"

# Function to display usage information
function show_usage() {
    echo "Usage: $0 [OPTIONS] [ARGUMENTS]"
    echo "Options:"
    echo "  -s, --stage3 FILE   Specify custom stage3"
    echo "  -f, --flags FILE    Specify custom package.use"
    echo "  -p, --packageset    Specify custom set"
    echo "  -b, --binpkgs       Specify binpkg host"
    echo "  -r, --repo          Specify repository url"
    echo "  -t, --portagetree   Specify portage tree (*.tar.bz2)"
    echo "  -v, --verbose       Enable verbose mode"
    echo "  -h, --help          Display this help message"
}
# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--stage3)
            if [ -z "$2" ]; then
                echo "Error: The '-s' option requires an argument."
                show_usage
                exit 1
            fi
            stage3_file="$2"
            shift 2
            ;;
        -f|--flags)
            if [ -z "$2" ]; then
                echo "Error: The '-f' option requires an argument."
                show_usage
                exit 1
            fi
            packageuse_file="$2"
            shift 2
            ;;
        -p|--packageset)
            if [ -z "$2" ]; then
                echo "Error: The '-p' option requires an argument."
                show_usage
                exit 1
            fi
            packageset_file="$2"
            shift 2
            ;;
        -b|--binpkgs)
            if [ -z "$2" ]; then
                echo "Error: The '-b' option requires an argument."
                show_usage
                exit 1
            fi
            binpkgs_host="$2"
            shift 2
            ;;
        -r|--repo)
            if [ -z "$2" ]; then
                echo "Error: The '-r' option requires an argument."
                show_usage
                exit 1
            fi
            repo_url="$2"
            shift 2
            ;;
        -t|--portagetree)
            if [ -z "$2" ]; then
                echo "Error: The '-t' option requires an argument."
                show_usage
                exit 1
            fi
            portagetree="$2"
            shift 2
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done


# Main installer script
echo "Welcome to the Gentoo Installer!"

# Call functions to perform installation steps

# Partition /dev/sda1 - 1GB, /dev/sda2 - 1GB, /dev/sda3 - Rest of drive
echo "Partitioning the disk..."
partition_disk
echo "Disk partitioning complete."

# Format /dev/sda1 - fat32, /dev/sda2 - ext2, /dev/sda3 - btrfs
echo "Formating the disk..."
format_partitions
echo "Disk formating complete."

# Mount /dev/sda1 - efi, /dev/sda2 - boot, /dev/sda3 - btrfs - subvolume @rootfs
echo "Mounting the partitions..."
mount_partitions
echo "Mounting partitions complete."

# Network - provide ncurses network manager
echo "Setting up the network..."
#configure_network
echo "Setting up the network complete."

# The rest of this script assumes the disk is mounted to the DEST_DIR and networking is up
# Local directory to save the tarball

#===========================
echo "Installing stage 3..."
#===========================

pushd .

# Check if a file is provided as an argument
if [ -f "$stage3_file" ]; then
#if [ $# -eq 1 ] || [ $# -eq 2 ]; then
    file="$stage3_file"

    # Verify if the file exists
    if [ ! -e "$file" ]; then
        echo "Error: The specified file '$file' does not exist."
        exit 1
    fi

    # Check if the file has a .tar.xz extension
    if [[ "$file" == *.tar.xz ]]; then
        echo "Calculating the SHA-256 checksum of $file"
        # Calculate the actual SHA-256 checksum
        actual_checksum=$(calculate_sha256 "$file")
        # Display the calculated checksum
        echo "SHA-256 checksum = $actual_checksum"

        # Get the expected SHA256 checksum from the .sha256 file
        EXPECTED_SHA256=$(awk '/SHA256 HASH/{getline; split($0, a, " "); print a[1]}' "$(basename "$file").sha256")
        # Display the expected SHA-256 checksum"
        echo "SHA-256 checksum = $EXPECTED_SHA256"
        # Compare the actual checksum with the expected checksum
        if [ "$actual_checksum" = "$EXPECTED_SHA256" ]; then
            echo "Checksums match: File is valid."
        else
            echo "Checksums do not match: File is invalid."
#            exit 1
            LATEST_URL=""
        fi
        LATEST_URL=$file
    else
        echo "Error: Only .tar.xz files are supported for checksum verification."
#        exit 1
        LATEST_URL=""
    fi
else
    echo "No stage3 provided will attempt to download latest version."
#    cd /mnt/gentoo/rootfs

    # Try to download a stage 3 tarball
    stage3_filename=$(GentooGetStage3)

    # Check if the function exited with status code 1
    if [ $? -eq 1 ]; then
        echo "Error downloading stage 3 tarball."
        exit 1
    fi
    LATEST_URL=$stage3_filename
fi

# Check if LATEST_URL is empty
if [ -z "$LATEST_URL" ]; then
#    echo "LATEST_URL is empty."
    echo "No stage3 provided will attempt to download latest version."
#    cd /mnt/gentoo/rootfs

    # Try to download a stage 3 tarball
    stage3_filename=$(GentooGetStage3)

    # Check if the function exited with status code 1
    if [ $? -eq 1 ]; then
        echo "Error downloading stage 3 tarball."
        exit 1
    fi
    LATEST_URL=$stage3_filename

    exit 1
else
#    echo "LATEST_URL is not empty."
    echo "Using local stage3: $LATEST_URL"
fi
cp $LATEST_URL $DEST_DIR

# Extract the filename from LATEST_URL
FILENAME=$(basename "$LATEST_URL")

# Combine DEST_DIR and the extracted filename to get LATEST_FILE
LATEST_FILE="$DEST_DIR/$FILENAME"

# Test if the LATEST_FILE exits
if test -e "$LATEST_FILE"; then
    echo "Extracting $LATEST_FILE..."
    cd $DEST_DIR
    tar -xf $FILENAME
    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        echo "Extraction of $LATEST_FILE successful."
    else
        echo "Extraction of $LATEST_FILE failed."
        exit 1
    fi
else
    echo "Problems finding a stage3 tarball."
    exit 1
fi

popd

echo "Installing stage 3 complete."

#=====================================
echo "Writing configuration files..."
#=====================================

# Write /etc/fstab
generate_fstab

# Write /etc/portage/make.conf
while true; do
    # Prompt the user for input
    read -p "Generate make.conf? (yes/no): " user_input

    # Check if the user_input is not empty
    if [ "$user_input" == "yes" ]; then
        generate_make_conf
        break
    elif [ "$user_input" == "no" ]; then
        echo "User chose not to generate make.conf. Exiting without performing the action."
        break
    else
        echo "Invalid input. Please enter 'yes' or 'no'."
    fi
done

#===============================================
echo "Checking if a package use file was given."
#===============================================
# Check to install package use
if [ -f "$packageuse_file" ]; then
#if [ $# -eq 2 ]; then
    generate_packageuse $packageuse_file
fi

#===============================================
echo "Checking if a package set file was given."
#===============================================
# Check to install package set
if [ -f "$packageset_file" ]; then
#add to sets making a list here:
#gentoolkit
    generate_packageset $packageset_file
fi

#=========================================
echo "Checking if a repository was given."
#=========================================
# Repository - Portage Tree and distfiles
#repo_url="https://example.com/path/to/resource"

# Use curl to make a HEAD request and check the HTTP response status
if curl -s --head "$repo_url" | grep "HTTP/1.1 200 OK" >/dev/null; then
    echo "The website path exists: $repo_url"
else
    echo "The website path does not exist or there was an error: $repo_url"
fi

#==================================================
echo "Checking if a binary package host was given."
#==================================================
# binpkgs repo - Binary Packages
# Use ping to check if the host is on the network
if ping -c 1 "$binpkgs_host" &>/dev/null; then
    echo "The host $binpkgs_host is on the network."
    mkdir -p $DEST_DIR/var/cache/binpkgs
    echo "Syncing binary packages."
    rsync -a /var/cache/binpkgs/ /mnt/gentoo/rootfs/var/cache/binpkgs/
    echo "Done syncing binary packages."
#    mount /dev/dm-0 -o subvol=@binpkgs /mnt/gentoo/rootfs/var/cache/binpkgs/
else
    echo "The host $binpkgs_host is not on the network or is not responding to pings."
fi

#===========================================
echo "Checking if a portage tree was given."
#===========================================

pushd .

# Check if the file exists
if [ ! -e "$portagetree" ]; then
    echo "File $portagetree does not exist."
    exit 1
fi

# Check if it's a tar.bz2 file
if [[ "$portagetree" != *.tar.bz2 ]]; then
    echo "File $portagetree is not a tar.bz2 archive."
    exit 1
fi

if tar -tf portage-2023-09-24.tar.bz2 | grep -q '^gentoo/'; then
    echo "The archive contains a folder named 'gentoo'."
    # Extract the contents to the temporary directory
    cp $portagetree "$DEST_DIR/var/db/repos"
    LATEST_FILE="$DEST_DIR/var/db/repos/$portagetree"
    FILENAME=$portagetree

else
    echo "The archive does not contain a folder named 'gentoo'."
    echo "Install will try to download the latest portage tree."
    exit 1
fi
# Test if the LATEST_FILE exits
if test -e "$LATEST_FILE"; then
    echo "Extracting $LATEST_FILE..."
    cd "$DEST_DIR/var/db/repos"
    tar -xf $FILENAME
    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        echo "Extraction of $LATEST_FILE successful."
    else
        echo "Extraction of $LATEST_FILE failed."
        exit 1
    fi
else
    echo "Problems finding a portage tree tarball."
    exit 1
fi

popd

rsync -av --delete "bin/" "$DEST_DIR/usr/local/bin/"
#cp "bin/btrfs-df.sh" "$DEST_DIR/usr/local/bin"
#cp "bin/btrfs-send-clean.sh" "$DEST_DIR/usr/local/bin"
#cp "bin/btrfs-snapshot.sh" "$DEST_DIR/usr/local/bin"
#cp "bin/btrfs-subvoume-list.sh" "$DEST_DIR/usr/local/bin"
#cp "bin/gentoo-system-update.sh" "$DEST_DIR/usr/local/bin"
#cp "bin/stage.sh" "$DEST_DIR/usr/local/bin"

echo "Writing configuration files complete."

echo "Entering chroot environment..."
setup_gentoo_chroot
echo "Exiting chroot environment."
configure_bootloader

echo "Gentoo installation complete!"
exit


