#/bin/bash
#set -e
#set -x

#  Copyright © 2017 David Larsson <david.larsson@selfhosted.xyz>
#
#  debootstrap_devuan.sh is free software: you can redistribute it and/or
#+ modify it under the terms of the GNU General Public License as
#+ published by the Free Software Foundation, either version 3 of the
#+ License, or (at your option) any later version.
#
#  debootstrap_devuan.sh is distributed in the hope that it will be
#+ useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#+ of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#+ General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#+ along with debootstrap_devuan.sh.  If not, see
#+ <http://www.gnu.org/licenses/>.

# TODO automate adduser and grub-install.
# TODO set hostname and keyboard automatically

partitionForLuks(){ # U-IO -> IO
    read -p "$TDEV headers will now be erased, please press enter to continue" 
    wipefs --all "$TDEV" && printf '%s' "wipefs completed "
    head -c 3145728 /dev/urandom > "$TDEV"; sync
    # read -p "The automated partitioning will now start. Press enter to continue"
    # cfdisk
    if [ "$TABLE" = "msdos" ] ; then
	parted --script "$TDEV" mklabel "$TABLE" \
	       mkpart primary 0% 100% \
	       set 1 boot on
	TPART="${TDEV}1"
    elif [[ "$TABLE" = "GPT" ]] ; then
	parted --script "$TDEV" mklabel "$TABLE" \
	       mkpart primary 0% 100% \
	       set 1 boot on \
	       set 1 bios_grub on
	TPART="${TDEV}1"
    else printf '%s\n' "In method partitionForLuks: the label \"$label\" is not valid - must be one of msdos and GPT"
    fi
}

tpartToLuks(){ # U-IO -> IO
    read -p "$TPART will now be luksencrypted, please press enter to continue"
    cryptsetup luksFormat "$TPART"
    #cryptsetup -v --cipher serpent-xts-plain64 --key-size 512 --hash=whirlpool --iter-time 500 --use-random --verify-passphrase luksFormat "$TPART"
}

makeFS(){ # -> IO
    printf '%s\n' "deb http://packages.devuan.org/merged jessie-backports main" >> /etc/apt/sources.list
    apt-get update && apt-get install -y btrfs-tools
    mkfs.btrfs -f -L "$LABEL" /dev/mapper/"$LABEL"
    if [[ -n $BOOTPART ]] ; then mkfs.ext2 -L boot_fs "${BOOTPART}" ; fi
    #btrfs subvolume create /mnt/sv_root
    #umount /dev/mapper/fs_root
    #mount -o subvolid=257 /dev/mapper/fs_root /mnt
    #btrfs subvolume set-default 257 /mnt
    #btrfs filesystem show -m
}

mountFS(){ # -> IO
    mount /dev/mapper/"$LABEL" "$TMOUNT"
    if [[ -n $BOOTPART ]] ; then mkdir -p /mnt/boot && mount "$BOOTPART" "$TMOUNT"/boot ; fi
}

mountFSBinds(){ # -> IO
    # bind some virtual filesystems, until the new installation is booting
    # on it's own we can borrow these from the host.
    mkdir -p "$TMOUNT"/dev && mount --bind /dev "$TMOUNT"/dev
    mkdir -p "$TMOUNT"/sys && mount --bind /sys "$TMOUNT"/sys
    mkdir -p "$TMOUNT"/proc && mount --bind /proc "$TMOUNT"/proc
    mkdir -p "$TMOUNT"/dev/pts && mount --bind /dev/pts "$TMOUNT"/dev/pts
}

myDebootstrap(){ # -> IO
    sed -i.bak '/jessie-backports/s/#//g' /etc/apt/sources.list
    apt-get update && apt-get install -y btrfs-tools
    #for pkg in "${PKGS[@]}" ; do
    #  pkgs+="${pkg},"
    #done
    #debootstrap --include="${pkgs%,}" --arch amd64 jessie "$TMOUNT" http://auto.mirror.devuan.org/merged/
    debootstrap --arch amd64 jessie "$TMOUNT" http://auto.mirror.devuan.org/merged/
    # for yad 
    sed -i '/slavino.sk/s/#//g' /etc/apt/sources.list
    chroot "$TMOUNT" gpg --recv-keys "$yadkey"
    chroot "$TMOUNT" gpg --export --armor $yadkey | chroot "$TMOUNT" apt-key add - 
    cp /etc/apt/sources.list "$TMOUNT"/etc/apt/sources.list
    echo "pkgInstall finished"
}

postInstall(){ # U-IO -> IO
    pkgInstall(){
	# define some package groups for installation (not nicely grouped so far)
	PKG0=(ca-certificates wireless-tools wpasupplicant netbase wget curl resolvconf openvpn fail2ban btrfs-tools extlinux cryptsetup ntp sudo rfkill bash-completion info)
	PKG1=(make gcc git dh-autoreconf libgcrypt20-dev libimlib2-dev python-pip)
	PKG2=(less htop lshw)
	PKG3=(zile emacs mpd mpv terminology rxvt-unicode shellcheck iceweasel)
	PKG4=(qemu libvirt0)
	PKGS=("${PKG0[@]}" "${PKG1[@]}" "${PKG2[@]}" "${PKG3[@]}" "${PKG4[@]}")
	chroot "$TMOUNT" apt-get install -y "${PKGS[@]}"
	# Symlink is because installing btrfs-progs or extlinux complained about this:
	chroot "$TMOUNT" ln -s /bin/fsck.btrfs /sbin/fsck.btrfs
	chroot "$TMOUNT" service ntp start
    }
    # Locales
    chroot "$TMOUNT" apt-get update
    chroot "$TMOUNT" apt-get install -y locales
    printf '%s\n' "en_US.UTF-8 UTF-8" >> "${TMOUNT}"/etc/locale.gen
    chroot "$TMOUNT" locale-gen
    chroot "$TMOUNT" dpkg-reconfigure locales
    dpkg-reconfigure tzdata
    #echo 'Europe/Stockholm > /etc/timezone
    #dpkg-reconfigure --frontend noninteractive tzdata
    dpkg-reconfigure keyboard-configuration # from: https://wiki.debian.org/Keyboard
    service keyboard-setup restart

    pkgInstall
    chroot "$TMOUNT" passwd
    chroot "$TMOUNT" usermod $username -aG sudo
    printf '%s\n' "Defaults targetpw" >> "$TMOUNT"/etc/sudoers
    chroot "$TMOUNT" apt-get -t jessie-backports install -y dracut-core linux-base "$kernel"
    if [[ -n $wifi_driver_path ]] ; then
	cp "$wifi_driver_path" "${TMOUNT}"/root/ && chroot "${TMOUNT}" dpkg -i /root/$wifi_driver 
    fi

    # Hostname - below commands sets the hostname and will break the internet connection in chroot
    # see https://bugzilla.redhat.com/show_bug.cgi?id=751640
    files=(/etc/hostname /etc/hosts /etc/mailname /etc/exim4/update-exim4.conf.conf)
    for file in "${files[@]}" ; do
	sed -i.bak "s/refracta/${hostname}/g"
    done
    printf '%b\n' "127.0.0.1\t$hostname" >> "$TMOUNT"/etc/hosts # %b instead of %s means interpret backslash characters.
    hostname "$hostname"
    /etc/init.d/hostname.sh start # probably useless.
    dpkg-reconfigure exim4-config # don't need both this and changing the mail-files above?
    printf '%s\n' "Method post-install has finished."
}

f_do_Buttersink_Setup(){ # todo, -> IO
    chroot "$TMOUNT" btrfs subvolume snapshot -r / /snapshot
    chroot "$TMOUNT" mkdir -p /root/bin
    chroot "$TMOUNT" git clone https://github.com/AmesCornish/buttersink.git /root/bin/
}

f_do_NetworkSetup(){ # U-IO -> IO
    read -p "Wireless or wired internet (1/2): " medium
    read -p "Auto(dhcp) or static ip? (auto/static) " addressation    
    if [[ $medium = 1 ]] ; then
	read -p "Please enter the wireless network ssid: " ssid
	read -p "Please enter the wireless password: " psk
	if [[ $addressation = "auto" ]] ; then
cat <<EOT >> /etc/network/interfaces.d/"${ssid}"
auto wlan0
iface "${ssid}" inet dhcp
  wpa_ssid "$ssid"
  wpa-psk "$psk"
EOT
        elif [[ $addressation = "static" ]] ; then
            read -p "Host-address ip? " ip
            read -p "Network ip? " netip
            read -p "Netmask? " netmask
            read -p "Broadcast address? "
            read -p "Gateway address? "
cat <<EOF >> /etc/network/interfaces.d/"${ssid}"
auto wlan0
iface wlan0 inet static
  wpa_ssid "$ssid"
  wpa-psk "$psk"
  address 192.168.1.5
  network 192.168.1.0
  netmask 255.255.255.0
  broadcast 192.168.1.255
  gateway 192.168.1.1

EOF
        fi
    elif [[ $medium = 2 ]] && [[ $addressation = "static" ]] ; then
        read -p "Host-address ip? " ip
        read -p "Network ip? " netip
        read -p "Netmask? " netmask
        read -p "Broadcast address? " broadcast
        read -p "Gateway address? " gateway
cat <<EOF >> /etc/network/interfaces.d/eth0
auto eth0
iface eth0 inet6 auto
iface eth0 inet static
  address $ip
  network $netip
  netmask $netmask
  broadcast $broadcast
  gateway $gateway

EOF
        read -p "Do you want to set specific nameservers? (y/n) "
        if [[ $REPLY = y ]] && [[ -n $ssid ]] ; then
cat <<EOF >> /etc/network/interfaces.d/"${ssid}"
  # ovpn nameservers
  dns-nameservers 192.165.9.158 46.227.67.134
EOF
        elif [[ $REPLY = y ]] && [[ -z $ssid ]] ; then
cat <<EOF >> /etc/network/interfaces.d/eth0
  # ovpn nameservers
  dns-nameservers 192.165.9.158 46.227.67.134

EOF
        fi
    fi
}

bootloaderInstall(){ # U-IO -> IO
    # GRUB, at encrypted root partition with keyfile.
    dd bs=512 count=4 if=/dev/urandom of="${TMOUNT}"/crypto_keyfile.bin
    cryptsetup luksAddKey "${TPART}" "${TMOUNT}"/crypto_keyfile.bin
    chmod 000 /crypto_keyfile.bin
    # Were unable to build initramfs properly with initramfs-tools for
    # automated use of the keyfile. This is just here for reference.
    f_initramfs-tools(){
	# in Arch GNU/Linux we can regenerate initramfs which grub
	# loads to memory, by using the FILES=<keyfile> and mkinitcpio
	# -p but this is devuan, so we make a custom (but trivial)
	# hook.
cat <<'EOF' > "$TMOUNT"/etc/initramfs-tools/hooks/crypto_keyfile
!/bin/sh
cp /crypto_keyfile.bin "${DESTDIR}"
EOF
	chmod +x "$TMOUNT"/etc/initramfs-tools/hooks/crypto_keyfile
    }
    f_dracut(){
	#  https://bugzilla.redhat.com/show_bug.cgi?id=751640
	printf '%s\n' 'install_items="/crypto_keyfile.bin"' >> "$TMOUNT"/etc/dracut.conf.d/10-decrypt.conf 
	chroot "$TMOUNT" dracut --host-only --force /boot/initrd.img-"${kernel#linux-image-}" "${kernel#linux-image-}"
    }
    f_grubInstall(){
	chroot "$TMOUNT" apt-get install -y grub-pc
	printf '%s\n' "GRUB_ENABLE_CRYPTODISK=y" >> "$TMOUNT"/etc/default/grub # it says to add =1 instead of =y but this is gnu grub bug #41524.
	printf '%s\n' 'GRUB_PRELOAD_MODULES="luks,cryptdisk"' >> "$TMOUNT"/etc/default/grub
	sed -i 's/GRUB_CMDLINE_LINUX//g' && printf '%s\n' "GRUB_CMDLINE_LINUX=\"cryptdevice=${TPART}:fs_root\"" >> "$TMOUNT"/etc/default/grub
	printf '%s\n' "fs_root ${TPART} /crypto_keyfile.bin luks,keyscript=/bin/cat" >> "$TMOUNT"/etc/crypttab
	#chroot "$TMOUNT" update-initramfs -u
	chroot "$TMOUNT" grub-mkconfig -o /boot/grub/grub.cfg
	#chroot "$TMOUNT" grub-install "$TDEV"
	chroot "$TMOUNT" update-grub
	chroot "$TMOUNT" chmod -R g-rwx,o-rwx /boot
    }
    desktopInstall(){
    if [[ "$desktop" = "xmonad" ]] ; then
	chroot "$TMOUNT" git clone https://github.com/methuselah-0/my-xmonad-config /home/"$username"/.xmonad
	chmod u+x "${TMOUNT}"/home/"${username}"/.xmonad/install-devuan.sh
	chroot "$TMOUNT" ./home/"$username"/install-devuan.sh "$username" # this will fix keyboard-configuration
    elif [[ "$desktop" = "xfce4" ]] ; then
	chroot apt-get install -y xfce4
    fi
    }
    f_dracut
    f_grubInstall
    chroot "$TMOUNT" adduser "$username" # TODO automate this step
    chroot "$TMOUNT" usermod "$username" -aG sudo
    desktopInstall    
}

myGenFstab(){ # -> IO
    local luks="$(blkid | grep "$LABEL" | awk ' { print $3 } ' | sed 's/PART//')"
    luks+=" / btrfs defaults 0 1"
    mkdir -p "${TMOUNT}"/etc
    printf '%s\n' "$luks" > "${TMOUNT}"/etc/fstab
    #if [[ -n "$BOOTPART" ]] ; then
#	local boot="$(blkid | grep "$TDEV" | grep -v "LUKS" | awk ' { print $3 } ')"
#	boot+=" /boot ext2 defaults 0 2"
#	printf '%s\n' "$boot" >> "${TMOUNT}"/etc/fstab
 #   fi
}

umountFS(){ # -> IO
    umount -l "$TMOUNT"/sys
    umount -l "$TMOUNT"/proc
    umount -l "$TMOUNT"/dev/pts
    umount -l "$TMOUNT"/dev    
    umount -l "$TMOUNT"
}

main(){
    # Edit these to your liking. Kernel and yad-key will break
    # eventually since this script will not be maintained.
    # You should set correct wifi-driver after looking at
    # /home/user/wireless-drivers and reading the README there.
    username="user1"
    hostname="amilo"
    desktop="xmonad" # either xfce4 or xmonad
#    kernel="linux-image-4.9.0-2-grsec-amd64" # this is because the virtual package linux-image-grsec-amd64 weren't able to load the specific package version for some reason.
    kernel="linux-image-4.9.0-0.bpo.3-amd64"
    TDEV="/dev/sda"
    LABEL="fs_root"
    TMOUNT="/mnt"
    TABLE="msdos" # using GPT has led to grub-install invalidating the LUKS partition.
    TPART="/dev/sdb1" # determined by above
    wifi_driver_path="/home/user/wireless-drivers/firmware-iwlwifi_0.43_all.deb"
    wifi_driver="firmware-iwlwifi_0.43_all.deb"
    yadkey='FFF06A93' # gpg key found in refracta usb install image in /etc/apt/sources.list    
    LIBREBOOT="no" # not yet implemented. Later you can set this to "yes" if you wish to boot from flash memory and not install grub-partition.
    BOOTPART='' # determined by above
    # ------------------------- #
    partitionForLuks # sets TPART
    tpartToLuks
    cryptsetup luksOpen "$TPART" "$LABEL"
    makeFS
    mountFS
    # Preparing the chroot environment # copy the mounted file systems
    #table. It keeps the df command happy (will be overwritten upon boot)
    mkdir -p ${TMOUNT}/etc && cp /etc/mtab ${TMOUNT}/etc/mtab
    myDebootstrap
    mountFSBinds # must run this after debootstrap and prior to postInstall
    myGenFstab
    postInstall ## fs-binds are necessary for installing grub etc.
    bootloaderInstall
    f_do_NetworkSetup
    umountFS && cryptsetup luksClose "$LABEL"
}
main

#mkdir -p  /mnt/lib/modules
#mv    /mnt/boot   /mnt/boot-origin
#mv    /mnt/etc/network   /mnt/etc/network-origin
