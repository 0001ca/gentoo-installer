#!/bin/bash
#
#=====
#Sound
#=====
#
#Display Sound Cards
#-------------------
# cat /proc/asound/cards
#Output:
#~~~~~~~
# 0 [HDMI           ]: HDA-Intel - HDA Intel HDMI
#                      HDA Intel HDMI at 0xf723c000 irq 53
# 1 [PCH            ]: HDA-Intel - HDA Intel PCH
#                      HDA Intel PCH at 0xf7238000 irq 50
#
#Select the Default Sound Card
#-----------------------------
# nano /etc/aound.conf
##Replace 1 with the number for the sound card
#pcm.!default {
#    type hw
#    card 1
#}
#
#ctl.!default {
#    type hw
#    card 1
#}
#
#==========
#UUID Stuff
#==========
#Change the UUID on the encrypted partition /dev/sdaX
# sudo cryptsetup luksUUID --uuid=<the new UUID> /dev/sdaX
#Display btrfs filesystem partition UUID
# sudo btrfs filesystem show
#Change the UUID on the btrfs partition - *drive must be offline not mounted
# sudo btrfstune -U e0c5b943-1c02-44a2-bbaf-87ebda5e363b /dev/sdaX
#
#==========
#QEMU Stuff
#==========
# sudo qemu-img create debian12.img 10G
#
#
#=========
#INITRAMFS
#=========
#
# Ref - https://wiki.gentoo.org/wiki/Custom_Initramfs
#
#
#CREATE A INITRAMFS
#==================
#
#Create a rootfs directory structure
#-----------------------------------
# mkdir --parents /usr/src/initramfs/{bin,dev,etc,lib,lib64,mnt/root,proc,root,sbin,sys}

#Copy over device files
#----------------------
# cp --archive /dev/{null,console,tty,sda1} /usr/src/initramfs/dev/
#
#BUSYBOX instead of manual
#-------------------------
# USE="sys-apps/busybox static -pam" emerge --ask --verbose sys-apps/busybox
# cp --archive /bin/busybox /usr/src/initramfs/bin/busybox
#
#MANUAL way by using ldd to add all the files you require
#--------------------------------------------------------
#
#List all the dependancies of nano
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ldd /bin/nano
#Output: - shows the dependend files needed to be included in the initramfs
#linux-vdso.so.1 (0x00007ffc0ddf8000)
#libncursesw.so.6 => /lib64/libncursesw.so.6 (0x00007f1ae7e5c000)
#libtinfow.so.6 => /lib64/libtinfow.so.6 (0x00007f1ae7e1c000)
#libc.so.6 => /lib64/libc.so.6 (0x00007f1ae7c4c000)
#/lib64/ld-linux-x86-64.so.2 (0x00007f1ae7f0b000)
#
#CREATE THE INIT SCRIPT
#----------------------
# nano /usr/src/initramfs/init
#minimalistic /init example
##!/bin/busybox sh

## Mount the /proc and /sys filesystems.
#mount -t proc none /proc
#mount -t sysfs none /sys
#
## Do your stuff here.
#echo "This script just mounts and boots the rootfs, nothing else!"
#
## Mount the root filesystem.
#mount -o ro /dev/sda1 /mnt/root
#
## Clean up.
#umount /proc
#umount /sys
#
## Boot the real thing.
#exec switch_root /mnt/root /sbin/init
#
#
#	chmod +x /usr/src/initramfs/init
#	cd /usr/src/initramfs
# this next command writes to /boot
#	find . -print0 | cpio --null --create --verbose --format=newc | gzip --best > /boot/custom-initramfs.cpio.gz
#
#
#
#
#
#
#
#
#
#====
#SWAP
#====
# 	btrfs filesystem mkswapfile --size 16g --uuid clear /swap/swapfile
# OR
# 	truncate -s 0 swapfile
# 	chattr +C swapfile
# 	fallocate -l 2G swapfile
# 	chmod 0600 swapfile
# 	mkswap swapfile
# 	swapon swapfile
#
#=====
#CRYPT
#=====
# To format the root partition using LUKS, secured with a passphrase:
# 	cryptsetup luksFormat --key-size 512 /dev/sda3
# To open the encrypted partition: --> mapped to /dev/mapper/sda3_crypt
# 	cryptsetup luksOpen /dev/sda3 sda3_crypt
#======
# BTRFS
#======
#
# To format partition to btrfs
# 	mkfs.btrfs -L rootfs /dev/mapper/sda3_crypt
#
#Mount and Create Subvolumes Example
#===================================
# Mount the default volume for the root partition on /mnt/btrfs
#	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag /dev/mapper/sda3_crypt /mnt/btrfs/
#
# The new root filesystem will go onto a subvolume (activeroot) which is created on the mirror and then mounted to /mnt/gentoo
#	btrfs subvol create /mnt/btrfs/@root
#	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=@root /dev/mapper/sda3_crypt /mnt/gentoo
#
# Make subvolume for home - with compression
#	btrfs subvol create /mnt/btrfs/@home
#	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=@home /dev/mapper/sda3_crypt /mnt/gentoo/home
#
# Make sub volume for files - no compression
#	btrfs subvol create /mnt/btrfs/@files
#	mount -t btrfs -o defaults,noatime,autodefrag,subvol=@files /dev/mapper/sda3_crypt /mnt/gentoo/files
#
# List all the subvolumes
# 	btrfs subvolume list /
# Create a snapshot subvolume of /
#	/sbin/btrfs subvolume snapshot / "rootfs_${NOW}"
# Delete a subvolume snapshot of /
# 	btrfs subvolume delete rootfs_2023-08-31_11:34:32
#
#
#
#Disk Checking Commands
#======================
# sudo btrfs fi show
# sudo btrfs filesystem df /
# sudo btrfs fi usage /
#
#BTRFS Balance
#=============
#With BTRFS, it is possible to run out of space when writing an amount of data that is much less than the reported free space.
#
#This is because BTRFS starts every write in a freshly allocated chunk. But as the chunksize is static, and files come in all sizes, 
#much of the time a chunk is incompletely filled. That creates “allocated but not used” space that is the problem.
#
#You may see the problem better using the command btrfs fi usage. Divide the used-size by total-size to get the ratio of inefficient storage.
#
#BTRFS has a tool to "rebalance" your filesystem, called balance. Originally designed for balancing data stored across multiple drives, 
#it is also useful in single drive configurations though, to rebalance how data is stored within the allocation.
#
#By default, balance will rewrite all the data on the disk. This is probably unnecessary. Chunks will be unevenly filled, 
#but you can use the above-calculated ratio to filter, using the -d parameter to only rebalance chunks that are less than that ratio. 
#That will leave any partially filled chunks which are more-filled than the average.
#
#If the ratio was 0.66, use the following command:
# sudo btrfs balance start -dusage=66 /
#
#You can run the above command in the background by appending & and check on its status using:
# sudo btrfs balance status -v /
#
#Or continuously using:
# while :; do sudo btrfs balance status -v / ; sleep 60; done
#
#To see the difference, check out the final result using:
# btrfs filesystem df /
#
#
#
#Show Status of the Balance
#--------------------------
# sudo btrfs balance status -v /
#
#Start the Balance
#-----------------
# sudo btrfs balance start -dusage=66 /
#
#Example sending a snapshot through ssh
#You have snapshots of /home at /home/.snapshots/ like snapper does
#There is a snapshot named /home/.snapshots/23/snapshot
#You mounted a Btrfs subvolume in /mnt/BACKUP
#There is a directory /mnt/BACKUP/23/
# sudo btrfs send /home/.snapshots/23/snapshot | ssh store "btrfs receive /mnt/BACKUP/23"
#
#Snapshot
#========
# sudo /sbin/btrfs subvolume snapshot /mnt/btrfs/@win "/mnt/btrfs/snapshot/winbase"
#
#BTRFS Send/Recieve
#==================
#
#Change property of subvolume between read and write
#---------------------------------------------------
# sudo btrfs property set -ts /mnt/btrfs/snapshot/winbase ro true
#
#Send subvolume to another btrfs
#-------------------------------
# sudo btrfs send /mnt/btrfs/snapshot/winbase | sudo ssh store "btrfs receive /mnt/btrfs"
#	**First trasfer takes time because the entire file is moving - rsync might be faster the first time
#
#Snapshot after running with @win for awhile
# sudo /sbin/btrfs subvolume snapshot /mnt/btrfs/@win "/mnt/btrfs/snapshot/winsnap1"
#
#Send diff between two subvolume to another btrfs
#-------------------------------
# sudo btrfs send -p /mnt/btrfs/snapshot/base/win /mnt/btrfs/snapshot/auto/win | ssh store "btrfs receive /mnt/btrfs/snapshot/auto"
#
#List read or write property
#---------------------------
# sudo btrfs property list -ts /mnt/btrfs/@win
#
#
#
#======
#SPHINX
#======
# See: https://www.kernel.org/doc/html/v4.10/doc-guide/sphinx.html
#
#
#1. = with overline for document title:
#
#==============
#Document title
#==============
#
#2. = for chapters:
#
#Chapters
#========
#
#3. - for sections:
#
#Section
#-------
#
#4. ~ for subsections:
#
#Subsection
#~~~~~~~~~~
#
#
#
#
#
#TODO - a good unchroot, a backup of the filesystem instead of chrooting-auto unchroot ir chrooted and then backup zip to a location
#Build server will backup profile, portage, packages, scripts - distfiles and kernels are backed up to the external harddrive manually and are in lvm 
#
#Rsync Documents through SSH
#rsync -auve "ssh -p 22" /home/user/Documents user@88.1.1.19:/home/user/Documents
#
# Files you need for a stage3 install
# /boot/syslinux - directory
# /boot/kernel
# /boot/initramfs
# /lib/modules
# /lib/firmware
# /var/db/repos/gentoo/profiles/releases/17.0/need to see if all files from /etc/portage can be here or which ones
# package.use.force - need
#
# /etc/portage
# make.conf  make.profile  package.license  package.mask  package.use  repos.conf  savedconfig  sets
#
#		This is a simple script
#to quit a screen session
#screen -S uptv -X quit
#
#CHROOT_DIR="/mnt/funtoo"
#SCREEN_NAME="funtoo"
#
#to set a mysql password
#sudo emerge --config =dev-db/mysql-5.6.35
#
#Launch steam like this if having dri3 error
#symbol lookup error: /usr/lib/libxcb-dri3.so.0: undefined symbol: xcb_send_request_with_fds
#LIBGL_DRI3_DISABLE=1 steam
#
#Add this to the install scripts under games a new switch -g
#Minecraft
#wget http://s3.amazonaws.com/Minecraft.Download/launcher/Minecraft.jar
#Steam
#wget http://repo.steampowered.com/steam/archive/precise/steam_latest.tar.gz
#LibGLX error do the following
#cd ~/.local/share/Steam/ubuntu12_32/steam-runtime/i386/usr/lib/i386-linux-gnu
#ln -snf /usr/lib/gcc/x86_64-pc-linux-gnu/4.9.2/32/libstdc++.so.6 libstdc++.so.6
#
#
#
#
#===
#SSH
#===
#
#SSH without a password
#======================
# cd ~/.ssh/
#
#Create rsa key pair private and public
#--------------------------------------
# ssh-keygen -t rsa
#
#Appends the id_rsa.pub to the ssh servers ~/.ssh/authorized-keys
#----------------------------------------------------------------
# ssh-copy-id <server>
#
#Connect to server without a password
#------------------------------------
# ssh <server>

#To see all server settings
#--------------------------
# ssh -T
#
#Keys Created
#------------
#Private = ~/.ssh/id_rsa
#Public = ~/.ssh/id_rsa.pub
#When excepting finger prints make sure they match on both ends for security
#
#
function mount_gentoo_btrfs_scheme () {
# Format /dev/sdb2
#	 mkfs.btrfs /dev/sdb2
	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag /dev/sdb2 /mnt/btrfs/
# The new root filesystem will go onto a subvolume (activeroot) which is created on the mirror and then mounted to /mnt/gentoo
#        btrfs subvol create /mnt/btrfs/activeroot
	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=activeroot /dev/sdb2 /mnt/gentoo
# Make subvolume for home - with compression
#        btrfs subvol create /mnt/btrfs/home
	mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=home /dev/sdb2 /mnt/gentoo/home
# Make sub volume for files - no compression
#        btrfs subvol create /mnt/btrfs/files
	mount -t btrfs -o defaults,noatime,autodefrag,subvol=files /dev/sdb2 /mnt/gentoo/files
}
function chroot_it () {
	echo "chroot "$WORK_DIR
        # chroot the filesystem
	cd $WORK_DIR
	mount --rbind /dev $WORK_DIR/dev
	mount --make-rslave $WORK_DIR/dev
	mount -t proc /proc $WORK_DIR/proc
	mount --rbind /sys $WORK_DIR/sys
	mount --make-rslave $WORK_DIR/sys
	mount --rbind /tmp $WORK_DIR/tmp
	cp /etc/resolv.conf $WORK_DIR/etc
	env -i HOME=/root TERM=$TERM chroot . bash -l
}
function unmount_it () {
#	mounts=$(awk -F" " '{ print $2 }' /proc/mounts | grep $WORK_DIR | awk -F" " '{print $1}')
#	echo ${mounts} > /tmp/unmount_1.txt
#	sed -e 's/[[:space:]]\+/\n/g' < /tmp/unmount_1.txt > /tmp/unmount_2.txt
#	sed -e 's/.*/umount &/' /tmp/unmount_2.txt > /tmp/unmount_3.txt
#	sed '1!G;h;$!d' /tmp/unmount_3.txt > /tmp/unmount_0.sh
#	rm /tmp/unmount_1.txt
#	rm /tmp/unmount_2.txt
#	rm /tmp/unmount_3.txt
#	sh /tmp/unmount_0.sh
#	rm /tmp/unmount_0.sh
# This one line should be all you need to unmount
	unmount -lf $WORK_DIR
}
function start_screen () {
	if screen -S $SCREEN_NAME -Q select; then
		echo "Using existing screen"
	else
		#create a new screen session
		screen -d -m -S $SCREEN_NAME
	fi
}
function remote_build () {
	if [ "$SCREEN_NAME" != "" ]; then
	        if screen -S $SCREEN_NAME -Q select; then
        	        echo "Using existing screen"
                	screen -S $SCREEN_NAME -X -p 0 stuff $'echo "Reconnected to existing screen"\n'
        	else
#                	screen -d -m -S $SCREEN_NAME
#        	        screen -S $SCREEN_NAME -X -p 0 stuff $'ssh -p 2221 0001.ca\n'
#	                screen -S $SCREEN_NAME -X -p 0 stuff $'build\n'
		        echo "Please use the -s option to set a screen name."
	        fi
	        screen -d -R $SCREEN_NAME
	else
	        echo "Please use the -s option to set a screen name."
        	exit 1
	fi
}




function debug () {
	echo VERBOSE=$VERBOSE
	echo HELP=$HELP
	echo DRY_RUN=$DRY_RUN
	echo SCREEN_NAME=$SCREEN_NAME
	echo WORK_DIR=$WORK_DIR
	echo FILESYSTEM=$FILESYSTEM
}
function SetTimezoneSetHostname {
	# Setup Time Zone
	cp /usr/share/zoneinfo/Canada/Pacific /etc/localtime
	echo "Canada/Pacific" > /etc/timezone
	# Set hostname
	cd /etc
	echo "127.0.0.1 base.at.myplace base localhost" > hosts
	sed -i -e 's/hostname.*/hostname="base" /' conf.d/hostname
}
#========================================================================================
#=I N S T A L L  G E N T O O  2022-03-17=================================================
#========================================================================================
function InstallGentoo20220317 {
# Test is the working directory was given
	if [ "$WORK_DIR" != "" ]; then
# Trim / off the end of $WORK_DIR if it exists and move into $ROOTFS
		ROOTFS=$(echo "$WORK_DIR" | sed 's:/*$::')
# Move to the working directory
		rm -R $ROOTFS/installs
		mkdir $ROOTFS/installs
		cd $ROOTFS/installs
# Get the stage3 tarball
		wget http://localhost/installs/stage3-amd64-openrc-20221225.tar.xz
# Extract the stage 3 tarball
		cd $ROOTFS
		tar -xvf installs/stage3-amd64-openrc-20221225.tar.xz
# Set the time zone
		cp $ROOTFS/usr/share/zoneinfo/Canada/Pacific $ROOTFS/etc/localtime
		echo "Canada/Pacific" > $ROOTFS/etc/timezone
# Set hostname
		cd $ROOTFS/etc
		echo "127.0.0.1 base.localhost base localhost" > hosts
		sed -i -e 's/hostname.*/hostname="base" /' conf.d/hostname
# Get portage tree
		cd $ROOTFS/installs
		wget http://localhost/portage/portage-20220317.tar.bz2
		rm -R $ROOTFS/var/db/repos/gentoo
		mkdir $ROOTFS/var/db/repos/gentoo
		cd $ROOTFS/var/db/repos/gentoo
		tar -jxvf $ROOTFS/installs/portage-20220317.tar.bz2
# Get sets
		rm -R $ROOTFS/etc/portage/sets
		mkdir $ROOTFS/etc/portage/sets
		cd $ROOTFS/etc/portage/sets
		wget http://localhost/etc_portage/sets/desktop
		wget http://localhost/etc_portage/sets/full20230102
#
# Get portage configuration
		rm -R $ROOTFS/etc/portage/package.use
		rm -R $ROOTFS/etc/portage/package.license
		rm -R $ROOTFS/etc/portage/package.mask
		rm $ROOTFS/etc/portage/make.conf
		cd $ROOTFS/etc/portage
		wget http://localhost/etc_portage/make.conf
		wget http://localhost/etc_portage/package.use
		wget http://localhost/etc_portage/package.license
		wget http://localhost/etc_portage/package.mask
		rm -R $ROOTFS/etc/portage/sets
		mkdir $ROOTFS/etc/portage/sets
		cd $ROOTFS/etc/portage/sets
		wget http://localhost/etc_portage/sets/desktop
		wget http://localhost/etc_portage/sets/full20230102
#
# Get repos.conf/gentoo.conf
		mkdir $ROOFS/etc/portage/repos.conf
#
# Get fstab template
		rm $ROOTFS/etc/fstab
		cd $ROOTFS/etc
		wget http://localhost/installs/fstab
#
# Get slim.conf
		rm $ROOTFS/etc/slim.conf
		cd $ROOTFS/etc
		wget http://localhost/installs/slim.conf
#
# Get linux 5.15.85
		rm -R $ROOTFS/boot
		mkdir $ROOTFS/boot
		cd $ROOTFS/boot
		wget http://localhost/linux/linux-5.15.85/vmlinuz-5.15.85-gentoo-dist
		wget http://localhost/linux/linux-5.15.85/initramfs-5.15.85-gentoo-dist.img
		wget http://localhost/linux/linux-5.15.85/config-5.15.85-gentoo-dist
#
# Get modules 5.15.85
		cd $ROOTFS/installs
		wget http://localhost/linux/linux-5.15.85/modules-5.15.85-gentoo-dist.tar.bz2
		rm -R $ROOTFS/lib/modules
		mkdir $ROOTFS/lib/modules
		cd $ROOTFS/lib/modules
		tar -jxvf $ROOTFS/installs/modules-5.15.85-gentoo-dist.tar.bz2

#
# Get linux firmware 5.15.85
		cd $ROOTFS/installs
		wget http://localhost/linux/linux-5.15.85/linux-firmware-5.15.85.tar.bz2
		rm -R $ROOTFS/lib/firmware
		mkdir $ROOTFS/lib/firmware
		cd $ROOTFS/lib/firmware
		tar -jxvf $ROOTFS/installs/linux-firmware-5.15.85.tar.bz2
	else
		echo "You need to set a working directory with the -d option"
		echo "Exiting with 0"
		exit 0
	fi
}
#
function SelectDesktopProfile () {
	eselect profile set 5
}
#
function AddUser () {
	useradd -m -g users -G wheel,floppy,audio,cdrom,video,cdrw,usb,users,plugdev user
	passwd user
}
#========================================================================================
#=I N S T A L L  G E N T O O  L A T E S T================================================
#========================================================================================
function InstallGentooLatest {
# Test is the working directory was given
	if [ "$WORK_DIR" != "" ]; then
# Trim / off the end of $WORK_DIR if it exists and move into $ROOTFS
		ROOTFS=$(echo "$WORK_DIR" | sed 's:/*$::')
# Move to the working directory
		rm -R $ROOTFS/installs
		mkdir $ROOTFS/installs
		cd $ROOTFS/installs
# Get the stage3 tarball
		wget http://localhost/installs/stage3-amd64-openrc-latest.tar.xz
# Extract the stage 3 tarball
		cd $ROOTFS
		tar -xvf installs/stage3-amd64-openrc-latest.tar.xz
# Set the time zone
		cp $ROOTFS/usr/share/zoneinfo/Canada/Pacific $ROOTFS/etc/localtime
		echo "Canada/Pacific" > $ROOTFS/etc/timezone
# Set hostname
		cd $ROOTFS/etc
		echo "127.0.0.1 base.localhost base localhost" > hosts
		sed -i -e 's/hostname.*/hostname="base" /' conf.d/hostname
# Get portage tree - done in the chroot enviroment with emerge --sync
#		cd $ROOTFS/installs
#		wget http://localhost/portage/portage-20220317.tar.bz2
#		rm -R $ROOTFS/var/db/repos/gentoo
#		mkdir $ROOTFS/var/db/repos/gentoo
#		cd $ROOTFS/var/db/repos/gentoo
#		tar -jxvf $ROOTFS/installs/portage-20220317.tar.bz2
# Get sets
		rm -R $ROOTFS/etc/portage/sets
		mkdir $ROOTFS/etc/portage/sets
		cd $ROOTFS/etc/portage/sets
		wget http://localhost/etc_portage/sets/desktop
		wget http://localhost/etc_portage/sets/full20230102
#
# Get portage configuration
		rm -R $ROOTFS/etc/portage/package.use
		rm -R $ROOTFS/etc/portage/package.license
		rm -R $ROOTFS/etc/portage/package.mask
		rm $ROOTFS/etc/portage/make.conf
		cd $ROOTFS/etc/portage
		wget http://localhost/etc_portage/make.conf
		wget http://localhost/etc_portage/package.use
		wget http://localhost/etc_portage/package.license
		wget http://localhost/etc_portage/package.mask
		rm -R $ROOTFS/etc/portage/sets
		mkdir $ROOTFS/etc/portage/sets
		cd $ROOTFS/etc/portage/sets
		wget http://localhost/etc_portage/sets/desktop
		wget http://localhost/etc_portage/sets/full20230102
#
# Get fstab template
		rm $ROOTFS/etc/fstab
		cd $ROOTFS/etc
		wget http://localhost/installs/fstab
#
# Get slim.conf
		rm $ROOTFS/etc/slim.conf
		cd $ROOTFS/etc
		wget http://localhost/installs/slim.conf
#
# Get linux 5.15.85
		rm -R $ROOTFS/boot
		mkdir $ROOTFS/boot
		cd $ROOTFS/boot
		wget http://localhost/linux/linux-5.15.85/vmlinuz-5.15.85-gentoo-dist
		wget http://localhost/linux/linux-5.15.85/initramfs-5.15.85-gentoo-dist.img
		wget http://localhost/linux/linux-5.15.85/config-5.15.85-gentoo-dist
#
# Get modules 5.15.85
		cd $ROOTFS/installs
		wget http://localhost/linux/linux-5.15.85/modules-5.15.85-gentoo-dist.tar.bz2
		rm -R $ROOTFS/lib/modules
		mkdir $ROOTFS/lib/modules
		cd $ROOTFS/lib/modules
		tar -jxvf $ROOTFS/installs/modules-5.15.85-gentoo-dist.tar.bz2

#
# Get linux firmware 5.15.85
		cd $ROOTFS/installs
		wget http://localhost/linux/linux-5.15.85/linux-firmware-5.15.85.tar.bz2
		rm -R $ROOTFS/lib/firmware
		mkdir $ROOTFS/lib/firmware
		cd $ROOTFS/lib/firmware
		tar -jxvf $ROOTFS/installs/linux-firmware-5.15.85.tar.bz2
	else
		echo "You need to set a working directory with the -d option"
		echo "Exiting with 0"
		exit 0
	fi
}
#

function GetDebianStable {
	if [ "$WORK_DIR" != "" ]; then
		debootstrap stable $WORK_DIR http://httpredir.debian.org/debian/
		#
	else
		echo "You need to set a working directory with the -d option"
		exit 0
	fi
}
function GetScripts () {
	#Get the latest scripts from current build
	#	rm -R /root/$SCREEN_NAME/scripts
	#	mkdir -p /root/$SCREEN_NAME/scripts
	#	cd /root/$SCREEN_NAME/scripts
	#	wget -r -nH -nd -np -R index.html* http://0001.ca/funtoo/scripts/
	cd /root
	rm -R /root/0001.ca/funtoo/scripts
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/scripts/
	rsync -av --delete /root/0001.ca/funtoo/scripts/ /usr/local/bin/
	chmod -R 777 /usr/local/bin
}
function GetProfile () {
	#Get the latest profile from current build
	#       rm -R /root/$SCREEN_NAME/profile
	#	mkdir -p /root/$SCREEN_NAME/profile
	#	cd /root/$SCREEN_NAME/profile
	#	wget -r -nH -nd -np -R index.html* http://0001.ca/funtoo/profile/
	cd /root
	rm -R /root/0001.ca/funtoo/profile
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/profile/
	rsync -av --delete /root/0001.ca/funtoo/profile/sets/ /etc/portage/sets/
	rsync -av --delete /root/0001.ca/funtoo/profile/package.use/ /etc/portage/package.use/
	cp /root/0001.ca/funtoo/profile/package.mask /etc/portage/
	cp /root/0001.ca/funtoo/profile/package.unmask /etc/portage/
	cp /root/0001.ca/funtoo/profile/package.license /etc/portage/
	cp /root/0001.ca/funtoo/profile/package.accept_keywords /etc/portage/
}
function GetKernel480rc5 () {
	cd /root
	rm -R /root/0001.ca/funtoo/linux/kernel-4.8-rc5
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/linux/kernel-4.8-rc5/
}
function ExtractKernel480rc5 () {
	cd /usr/src
	tar -xf /root/0001.ca/funtoo/linux/kernel-4.8-rc5/linux-4.8-rc5.tar.xz
	rm linux
	ln -s linux-4.8-rc5 linux
	cp /root/0001.ca/funtoo/linux/kernel-4.8-rc5/config-x86_64-4.8-rc5 /usr/src/linux/.config
}

function CompileKernel480rc5 () {
	mount /boot
	cd /usr/src/linux
	make -j5
	make modules_install
	cp arch/x86_64/boot/bzImage /kernel-x86_64-4.8-rc5
	cp .config /config-x86_64-4.8-rc5
	genkernel --install --no-ramdisk-modules initramfs
	mv /boot/initramfs-genkernel-x86_64-4.8.0-rc5 /initramfs-x86_64-4.8-rc5
}

function GetAll () {
	cd /root
	rm -R /root/0001.ca/funtoo
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/config/
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/docs/
#	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/linux/
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/overlay/
#	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/packages/
#	wget -r --no-parent --reject distfiles --reject packages --reject "index.html*" http://0001.ca/funtoo/portage/
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/profile/
	wget -r --no-parent --reject "index.html*" http://0001.ca/funtoo/scripts/
	sudo mkdir /root/0001.ca/funtoo/filesystems
	cd /root/0001.ca/funtoo/filesystems 
	wget http://0001.ca/funtoo/filesystems/stage3.tar.xz
}



# Compile the kernel
function CompileKernel366 () {
	emerge genkernel  #do we need this probably for some tools
	#emerge vanilla-sources
	mkdir /root/gentoo-kernel
	cd /root/gentoo-kernel
	wget http://0001.ca/gentoo-kernel/kernel-3.6.6/linux-3.6.6.tar.gz
	wget http://0001.ca/gentoo-kernel/kernel-3.6.6/config-3.6.6_x86_64
	cd /usr/src/
	rm -R /usr/src/linux-3.6.6
	tar -zxvf /root/gentoo-kernel/linux-3.6.6.tar.gz
	ln -s linux-3.6.6 linux
	cd /usr/src/linux
	cp /root/gentoo-kernel/config-3.6.6_x86_64 /usr/src/linux/.config
	make menuconfig
	make oldconfig && make prepare
	make prepare
	make -j2
	make modules_install
	cp arch/x86_64/boot/bzImage /boot/kernel-3.6.6
	#genkernel --install --no-ramdisk-modules initramfs
	#cp /boot/initramfs-genkernel-x86_64-3.6.6 /boot/initramfs
	cp .config /boot/config-3.6.6
}
function KernelType () {
        while true; do
		echo "Please select a Kernel version."
		echo "1) linux-4.8.0-rc5"
		echo "2) linux-4.10"
            read -p "Please type your selection and press enter: " 12
            case $yn in
                [1]* ) GetKernel480rc5; break;;
                [2]* ) break;;
                * ) echo "Invalid selection.";;
            esac
        done
}

function KernelMenu () {
	#Get_Kernel
	while true; do
	    read -p "Download Kernel-4.8.0-rc5 ? " yn
	    case $yn in
	        [Yy]* ) GetKernel480rc5; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Kernel_Symbol_Link
	while true; do
	    read -p "Extract Kernel-4.8.0-rc5 and set symbolic link to /usr/src/linux ? " yn
	    case $yn in
	        [Yy]* ) ExtractKernel480rc5; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Run make menuconfig ?
	while true; do
	    read -p "Do you want to run make menuconfig ? " yn
	    case $yn in
	        [Yy]* ) cd /usr/src/linux; make menuconfig; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done 

	#Compile_Kernel
	while true; do
	    read -p "Do you want to Compile and Install Kernel-4.8.0-rc5 ? " yn
	    case $yn in
	        [Yy]* ) CompileKernel480rc5; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

}
#***************************************
#***************************************
#***************************************
#***************************************
function ManualUpdate () {
	#Update world
	#emerge --update --deep --with-bdeps=y --newuse world
	while true; do
	    read -p "Update World ?" yn
	    case $yn in
	        [Yy]* ) emerge --ask --update --deep --ignore-built-slot-operator-deps=y --with-bdeps=y --newuse world; exit;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done
	#Update system
	#emerge --update --deep --with-bdeps=y --newuse world
	while true; do
	    read -p "Update System ?" yn
	    case $yn in
	        [Yy]* ) emerge --ask --update --deep --with-bdeps=y --newuse system; exit;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Rsync Portage
	#emerge --sync
	while true; do
	    read -p "Sync Portage ?" yn
	    case $yn in
	        [Yy]* ) emerge --sync; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Update portage
	#emerge -lv portage
	while true; do
	    read -p "Update Portage ?" yn
	    case $yn in
	        [Yy]* ) emerge --ask -lv portage; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Update gcc
	#emerge -u gcc
	while true; do
	    read -p "Update GCC ?" yn
	    case $yn in
	        [Yy]* ) emerge -u gcc; gcc-config -l; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Update gcc continued
	# env-update && source /etc/profile
	# emerge --oneshot libtool
	# revdep-rebuild --library libstdc++.so.5
	while true; do
	    read -p "Update GCC continued ?" yn
	    case $yn in
	        [Yy]* )  env-update && source /etc/profile; emerge --oneshot libtool; revdep-rebuild --library libstdc++.so.5; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	while true; do
	    read -p "Run Perl Cleaner ?" yn
	    case $yn in
	        [Yy]* )  perl-cleaner all; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#rebuild broken packages
	#revdep-rebuild
	while true; do
	    read -p "Rebuild broken packages?" yn
	    case $yn in
	        [Yy]* ) revdep-rebuild.sh; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done

	#Remove unused packages
	#emerge --depclean
	while true; do
	    read -p "Remove unused packages" yn
	    case $yn in
	        [Yy]* ) emerge --ask --depclean; break;;
	        [Nn]* ) break;;
		* ) echo "Please answer yes or no.";;
	    esac
	done

	#Recompile the entire system
	#emerge -e system
	while true; do
	    read -p "Recompile the entire system?" yn
	    case $yn in
	        [Yy]* ) emerge --ask -e system; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done
}

function System_Update (){
#        GetScripts
#  	 GetProfile
#        emerge --sync
#        emerge -lv portage
#        emerge --update --deep --with-bdeps=y --newuse world
#        revdep-rebuild.sh
#	 emerge --depclean
#        perl-cleaner all
#	 haskell-updater
#	 python-updater	
	emerge --update --deep --with-bdeps=y --newuse world
}



function System_Upgrade () {
        while true; do
            read -p "This will uninstall all programs in the world and world_sets file.  Secondly, update the system.  Third, reinstall world and world_sets.  Are you sure you want to proceed? " yn
            case $yn in 
                [Yy]* ) echo "Starting Distribution Upgrade ... ";
			sleep 1;
		        mv /var/lib/portage/world /root/
		        mv /var/lib/portage/world_sets /root/
		        emerge --update --deep --with-bdeps=y --newuse world
		        emerge --update --deep --with-bdeps=y --newuse world
		        revdep-rebuild.sh
		        emerge --depclean
		        perl-cleaner all
		        GetScripts
		        GetProfile
		        rm -R /usr/portage
		        emerge --sync
		        emerge -lv portage
		        emerge --update --deep --with-bdeps=y --newuse world
		        emerge --update --deep --with-bdeps=y --newuse world
		        revdep-rebuild.sh
		        perl-cleaner all
		        mv /root/world_sets /var/lib/portage/
		        emerge --update --deep --with-bdeps=y --newuse world
		        emerge --update --deep --with-bdeps=y --newuse world
		        revdep-rebuild.sh
		        emerge --update --deep --with-bdeps=y --newuse world
		        mv /root/world /var/lib/portage/
	       		emerge --update --deep --with-bdeps=y --newuse world
			exit;;
                [Nn]* ) break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
}

#===============================================================================================
#===============================================================================================
#=============================== M E N U =======================================================
#===============================================================================================
#===============================================================================================

#
# Purpose - display output using msgbox
#  $1 -> set msgbox height
#  $2 -> set msgbox width
#  $3 -> set msgbox title
#
function display_output(){
	local h=${1-10}			# box height default 10
	local w=${2-41} 		# box width default 41
	local t=${3-Output} 	# box title
	dialog --backtitle "Linux Maintenance Script" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}
#========================================================================================
#========================================================================================
#========================================================================================
function show_date(){
	echo "Today is $(date) @ $(hostname -f)." >$OUTPUT
	display_output 6 60 "Date and Time"
}
#========================================================================================
#========================================================================================
#========================================================================================
function show_calendar(){
	cal >$OUTPUT
	display_output 13 25 "Calendar"
}
#========================================================================================
#=1  M A I N  M E N U====================================================================
#========================================================================================
function Menu_Main(){
	### display main menu ###
	dialog --clear  --help-button --backtitle "Linux Maintenance Script" \
	--title "[ M A I N - M E N U ]" \
	--menu "Use the arrow keys to choose the task \n\
Then Press Enter" 15 50 5 \
	Date/time "Displays date and time" \
	Calendar "Displays a calendar" \
	Editor "Start a text editor" \
	MC "Start a file browser" \
	Control_Panel "Modify system" \
	Exit "Exit to the shell" 2>"${INPUT}"

}
#========================================================================================
#=2  C O N T R O L  P A N E L   M E N U==================================================
#========================================================================================
function Menu_Control_Panel() {
	### display main menu ###
	dialog --clear  --help-button --backtitle "Linux Control Panel" \
	--title "[ C O N T R O L - P A N E L ]" \
	--menu "Use the arrow keys to choose the task \n\
Then Press Enter" 15 50 5 \
	Build "Chroot build server in a screen" \
	Install "Install filesystem" \
	Update "Update system" \
	Settings "Modify system settings" \
	System "System information" \
	Back "Back to main menu" 2>"${INPUT}"
}
#========================================================================================
#=3  I N S T A L L   M E N U=============================================================
#========================================================================================
function Menu_Install() {
	### display main menu ###
	dialog --clear  --help-button --backtitle "Linux Filesystem Installer" \
	--title "[ F I L E S Y S T E M - I N S T A L L E R ]" \
	--menu "Use the arrow keys to choose the task \n\
Then Press Enter" 15 50 5 \
	Stage3-20220317 "Install Gentoo 20220317" \
	Latest "Install Gentoo Latest" \
	Debian "Install Debian" \
	Back "Back to main menu" 2>"${INPUT}"
}
#========================================================================================
#=4  U P D A T E   M E N U===============================================================
#========================================================================================
function Menu_Update() {
	### display main menu ###
	dialog --clear  --help-button --backtitle "Linux Update" \
	--title "[ S Y S T E M - U P D A T E R ]" \
	--menu "Use the arrow keys to choose the task \n\
Then Press Enter" 15 50 5 \
	Manual "Manual update" \
	Current "Automated update" \
	Funtoo "Automated update" \
	Sets "Select/Deselect Software Sets" \
	Back "Back to main menu" 2>"${INPUT}"
}
#========================================================================================
#=5  S E T T I N G S   M E N U===========================================================
#========================================================================================
function Menu_Settings() {
	echo "Write script for settings here"
}
#========================================================================================
#=6  S Y S T E M  I N F O R M A T I O N  M E N U=========================================
#========================================================================================
function Menu_SystemInformation() {
	nouser=`who | wc -l`
	echo -e "User name: $USER (Login name: $LOGNAME)" >> /tmp/info.tmp.01.$$$
	echo -e "Current Shell: $SHELL"  >> /tmp/info.tmp.01.$$$
	echo -e "Home Directory: $HOME" >> /tmp/info.tmp.01.$$$
	echo -e "Your O/s Type: $OSTYPE" >> /tmp/info.tmp.01.$$$
	echo -e "PATH: $PATH" >> /tmp/info.tmp.01.$$$
	echo -e "Current directory: `pwd`" >> /tmp/info.tmp.01.$$$
	echo -e "Currently Logged: $nouser user(s)" >> /tmp/info.tmp.01.$$$

	if [ -f /etc/redhat-release ]
	then
	    echo -e "OS: `cat /etc/redhat-release`" >> /tmp/info.tmp.01.$$$
	fi

	if [ -f /etc/shells ]
	then
	    echo -e "Available Shells: " >> /tmp/info.tmp.01.$$$
	    echo -e "`cat /etc/shells`"  >> /tmp/info.tmp.01.$$$
	fi

	if [ -f /etc/sysconfig/mouse ]
	then
	    echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	    echo -e "Computer Mouse Information: " >> /tmp/info.tmp.01.$$$
	    echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	    echo -e "`cat /etc/sysconfig/mouse`" >> /tmp/info.tmp.01.$$$ 
	fi
	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	echo -e "Computer CPU Information:" >> /tmp/info.tmp.01.$$$ 
	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	cat /proc/cpuinfo >> /tmp/info.tmp.01.$$$

	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	echo -e "Computer Memory Information:" >> /tmp/info.tmp.01.$$$ 
	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	cat /proc/meminfo >> /tmp/info.tmp.01.$$$

	if [ -d /proc/ide/hda ]
	then
	    echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	    echo -e "Hard disk information:" >> /tmp/info.tmp.01.$$$ 
	    echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	    echo -e "Model: `cat /proc/ide/hda/model` " >> /tmp/info.tmp.01.$$$    
	    echo -e "Driver: `cat /proc/ide/hda/driver` " >> /tmp/info.tmp.01.$$$    
	    echo -e "Cache size: `cat /proc/ide/hda/cache` " >> /tmp/info.tmp.01.$$$    
	fi
	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	echo -e "File System (Mount):" >> /tmp/info.tmp.01.$$$ 
	echo -e "--------------------------------------------------------------------" >> /tmp/info.tmp.01.$$$ 
	cat /proc/mounts >> /tmp/info.tmp.01.$$$

	if which dialog > /dev/null
	then
	    dialog  --backtitle "Linux Software Diagnostics (LSD) Shell Script Ver.1.0" --title "Press Up/Down Keys to move" --textbox  /tmp/info.tmp.01.$$$ 30 120
	else
	    cat /tmp/info.tmp.01.$$$ |more
	fi

	#echo $(<"${INPUT}")
	echo "Back" 2>"${INPUT}"
	echo $(<"${INPUT}")
# Unblock for testing
# 	read -p "Test Break Point 1" yn
	MENU_PTR=2
	rm -f /tmp/info.tmp.01.$$$
}
#========================================================================================
#=7  B U I L D  M E N U==================================================================
#========================================================================================
function Menu_Build() {
	echo "Write your build script here"
}

#========================================================================================
#=I N I T   M E N U==================================================================
#========================================================================================
function INIT() {
	# get text editor or fall back to vi_editor
	vi_editor=$EDITOR

	# trap and delete temp files
	trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM
	INPUT=/tmp/menu.sh.$$

	# Storage file for displaying cal and date command output
	OUTPUT=/tmp/output.sh.$$
	MENU_PTR=1
	#
	# set infinite loop
	#
	while true
	do


	# make decsion
	case $MENU_PTR in
		1) Menu_Main;;
		2) Menu_Control_Panel;;
		3) Menu_Install;;
		4) Menu_Update;;
		5) Menu_Settings;;
		6) Menu_SystemInformation;;
		7) Menu_Build;;
		Exit) echo "Bye"; break;;
	esac

	menuitem=$(<"${INPUT}")
	echo $(<"${INPUT}")
#Unblock for testing
#	read -p "Test Break Point 2" yn
	# make decsion
	case $menuitem in
		Date/time)
			show_date;;
		Calendar)
			show_calendar;;
		Editor)
			nano;;
		MC)
			mc;;
		Build)
			MENU_PTR=7;;
		Install)
			MENU_PTR=3;;
		Update)
			MENU_PTR=4;;
		Settings)
			MENU_PTR=5;;
		System)
			MENU_PTR=6;;
		Control_Panel)
			MENU_PTR=2 ;;
		Sync_Scripts)
			GetScripts
			pause;;
		Sync_Scripts)
			GetScripts;;
		Stage3-20220317)
			InstallGentoo20220317;;
		Stable)
			pause;;
		Latest)
			InstallGentooLatest;;
		Funtoo)
			pause;;
		Debian)
			pause;;
		rpione)
			pause;;
		rpitwo)
			pause;;
		Manual)
			ManualUpdate
			pause;;
		Current)
			while true; do
			read -p "Are you sure you want to update your system to the latest binary build?" yn
			case $yn in
				[Yy]* ) System_Update; break;;
				[Nn]* ) break;;
				* ) echo "Please answer yes or no.";;
			esac
			done
			pause;;
		Rolling)
			while true; do
			read -p "Are you sure you want to update your system to the latest source funtoo?" yn
			case $yn in
				[Yy]* ) System_Upgrade; break;;
				[Nn]* ) break;;
				* ) echo "Please answer yes or no.";;
			esac
			done
			pause;;
		Back) MENU_PTR=1;;
		Exit) echo "Bye"; break;;
	esac
	done
	# if temp files found, delete em
	[ -f $OUTPUT ] && rm $OUTPUT
	[ -f $INPUT ] && rm $INPUT
}

function Install_OS () {
	if [ "$INSTALL" == "1" ]; then
		echo "Call install os 1 script here"
	elif [ "$INSTALL" == "2" ]; then
		echo "Call install os 2 script here"
	else
		echo "There is no option available for that selection"
		exit 1
	fi
}

#========================================================================================
#=H E L P  A B O U T  S C R I P T========================================================
#========================================================================================
function usage () {
	echo " Usage : Install, Backup and Chroot Utility"
	echo "	  Example 1:- Install Gentoo Latest in a screen "
	echo "	            # stage -d /mnt/gentoo -s gentoo -i 2"
	echo "	  Example 2:- Create a chroot enviroment in a screen "
	echo "	            # stage -c -d /mnt/gentoo -s gentoo"
	echo "	  Example 3:- Reattach to screen "
	echo "	            # stage -s gentoo"
	echo "	  Example 4:- Run Manual Update of Live System "
	echo "	            # stage -u"
	echo "	  stage"
	echo "        	-v | --verbose )     VERBOSE=true;;"
 	echo "		-h | --help )        HELP=true;;"
	echo "		-q | --dry-run )     DRY_RUN=true;;"
	echo "		-c | --chroot )      CHROOT=true;;"
	echo "		-u | --update )      UPDATE=true;;"
	echo "		-k | --kernel )      KERNEL=true;;"
	echo "		-i | --install )     INSTALL = "
	echo "		-g | --gui )         GUI=true;;"
	echo "		-s | --screen-name ) SCREEN_NAME = "
	echo "		-d | --work-dir )    WORK_DIR = Directory containing filesystem to be worked on"
	echo "		-b | --backup )      BACKUP = Directory to store backups.  Note backups are stored as the screen name."
	echo "		-r | --roll-dir )    ROLL_DIR = Directory containing backup filesystem to restore.  Note that the screen name must be set to a folder in this directory."
}


###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
##########	 SCRIPT STARTS HERE
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
###################################################################################################################
#
#
#continue only if this script was run as the superuser
whoami_var=$(whoami)
#echo $whoami_var
if [ "$whoami_var" = "root" ]; then
#	echo ""
	SUPERUSER=true
else
	SUPERUSER=false
#	echo "You must restart this script as the superuser"
	exit 0
fi

#superuser has been confirmed
VERBOSE=false
HELP=false
DRY_RUN=false
INSTALL=false
UPDATE=false
KERNEL=false
CHROOT=false
GUI=false
SCREEN_NAME=
WORK_DIR=
BACKUP_DIR=
ROLL_DIR=
FILESYSTEM=
DEBUG=false

while true; do
    case "$1" in
	-v | --verbose ) VERBOSE=true;;
	-h | --help )    HELP=true;;
	-q | --dry-run ) DRY_RUN=true;;
	-c | --chroot )  CHROOT=true;;
	-u | --update )  UPDATE=true;;
	-k | --kernel ) KERNEL=true;;
	-i | --newinstall ) NEWINSTALL="$2"; shift;;
	-g | --gui ) GUI=true;;
	-s | --screen-name ) SCREEN_NAME="$2"; shift;;
	-d | --work-dir ) WORK_DIR="$2"; shift;;
	-b | --backup-dir ) BACKUP_DIR="$2"; shift;;
	-r | --roll-dir ) ROLL_DIR="$2"; shift;;
        -- ) ;;
        * ) if [ -z "$1" ]; then break; else echo "$1 is not a valid option"; usage; exit 1; fi;;
    esac
    shift
done

if [ "$DEBUG" = true ]; then
	debug
fi


if [ "$HELP" = true ]; then
	usage
	exit 0
fi

if [ "$GUI" = true ]; then
	INIT
	exit 0
fi



if [ "$UPDATE" = true ]; then
	if [ "$CHROOT" = true ]; then
		echo "WRITE CODE HERE : To update in screen command"
		exit 0
	else
		if [ "$VERBOSE" = true ]; then
			ManualUpdate
			exit 0
		else
			System_Update
			exit 0
		fi
	fi
fi
if [ "$KERNEL" = true ]; then
	KernelMenu
	exit 0
fi

if [ "$NEWINSTALL" != "" ]; then
        if [ "$WORK_DIR" = "" ]; then
                echo "You need to specify a working directory with the -d option"
        	exit 1
        fi
	while true; do
	    read -p "Are you sure you want to install the new operating system ?" yn
	    case $yn in
	        [Yy]* ) Install_OS; break;;
	        [Nn]* ) break;;
	        * ) echo "Please answer yes or no.";;
	    esac
	done
	exit 0
fi


#the following code is for chrooting in a screen
DEBUG=false
if [ "$DEBUG" = true ]; then
	echo $SCREEN_NAME
	read -p "Press enter to continue"
fi

if [ "$CHROOT" = true ]; then
	if [ "$SCREEN_NAME" != "" ]; then
		#start new screen
		start_screen

		if [ "$DEBUG" = true ]; then
			echo "Screen (" $SCREEN_NAME ") should be started now"
			screen -list
			read -p "Press enter to continue"
		fi


		if [ "$WORK_DIR" = "/" ]; then
			echo "Please change the -d option to a filesystem other than the current running filesystem."
			exit 1
		fi

		#Chroot in a started screen
		if [ "$WORK_DIR" != "" ]; then
#
#
#--------------------------------------
#The folloing screen command
#	if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
#  		echo "We are chrooted!"
#	else
#		echo "Chrooting the following directory: "$WORK_DIR
#	        # chroot the filesystem
#		cd $WORK_DIR
#		mount --rbind /dev $WORK_DIR/dev
#		mount --make-rslave $WORK_DIR/dev
#		mount -t proc /proc $WORK_DIR/proc
#		mount --rbind /sys $WORK_DIR/sys
#		mount --make-rslave $WORK_DIR/sys
#		mount --rbind /tmp $WORK_DIR/tmp
#		cp /etc/resolv.conf $WORK_DIR/etc
#		env -i HOME=/root TERM=$TERM chroot . bash -l
#	fi
#
			screen -S $SCREEN_NAME -X -p 0 stuff $'if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then echo "We are chrooted!"; else echo "Chrooting the following directory: "'$WORK_DIR' cd '$WORK_DIR'; mount --rbind /dev '$WORK_DIR'/dev; mount --make-rslave '$WORK_DIR'/dev; mount -t proc /proc '$WORK_DIR'/proc; mount --rbind /sys '$WORK_DIR'/sys; mount --make-rslave '$WORK_DIR'/sys; mount --rbind /tmp '$WORK_DIR'/tmp; cp /etc/resolv.conf '$WORK_DIR'/etc; cd '$WORK_DIR'; env -i HOME=/root TERM='$TERM' chroot . bash -l; fi;\n'
			screen -S $SCREEN_NAME -X -p 0 stuff $'export PS1=(chroot_'$SCREEN_NAME')"/ # "\n'
#
#----------------------------------------
#The following screen command
#if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
#	echo "We are chrooted!"
#else
#	echo "Chroot Failed!"
#fi
			screen -S $SCREEN_NAME -X -p 0 stuff $'if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then echo "We are chrooted"; export PS1="("chroot_'$SCREEN_NAME'") / # "; else echo "Chroot failed are you sure there is a filesystem to chroot in"'$WORK_DIR'"?"; fi;\n'
#--------------------------------------
			if [ "$DEBUG" = true ]; then
				echo "Screen (" $SCREEN_NAME ") should be started now"
				read -p "Press enter to continue"
			fi
			screen -d -R $SCREEN_NAME
		else
			echo "Please use the -d option to point at a filesystem."
			exit 1
		fi
	else
		echo "Please use the -s option to set a screen name."
		exit 1
	fi
#	unmount_it
else
#-c switch is not set
	if [ "$SCREEN_NAME" != "" ]; then
		echo "-s has a value and -c is not set"
		remote_build
	else
		echo "-s has no value and -c is not set"
	fi
fi
#echo "End of stage script"
exit 0


#if [ "$SUPERUSER" = true ]; then
##       echo "This script is running as the superuser."
#else
##       echo "This script is running by the user."
#fi



# Preparing the intermediate build chroot for upgrades
# We want to use the new stage3 to build the old gentoo mounted in /mnt/build/mnt/host
#root #mkdir -p /mnt/build
#root #tar -xf /path/to/stage3-somearch-somedate.tar.bz2 -C /mnt/build
#root #mount --rbind /dev /mnt/build/dev
#root #mount --rbind /proc /mnt/build/proc
#root #mount --rbind /sys /mnt/build/sys
#root #mkdir -p /mnt/build/mnt/host
#root #mount --rbind / /mnt/build/mnt/host
#cp -L /etc/resolv.conf /mnt/build/etc/
#root #chroot /mnt/build
#root #source /etc/profile
#root #export PS1="(chroot) ${PS1}"
#(chroot) root #emerge --sync
#(chroot) root #emerge --root=/mnt/host --config-root=/mnt/host --verbose --oneshot sys-apps/portage
#********* Important:
#Do not forget to add --root=/mnt/host --config-root=/mnt/host to all emerge commands executed within the chroot! Otherwise the chroot itself is updated rather than the (old) live system.
#(chroot) root #emerge --root=/mnt/host --config-root=/mnt/host --update --newuse --deep --ask @world
