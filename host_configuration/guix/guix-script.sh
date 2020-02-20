set -e
f_do_NetworkSetup(){ # U-IO -> IO
read -p "Wireless or wired internet (1/2): "
if [[ $REPLY = 1 ]] ; then
  read -p "Please enter the wireless network ssid: " ssid
  read -p "Please enter the wireless password: " psk
cat <<EOT > ~/wpa.conf
network={
  ssid="$ssid"
  key_mgmt=WPA-PSK
  psk="$psk"
}
EOT
wpa_supplicant -c ~/wpa.conf -i wlp2s0 -B
dhclient -v wlp2s0
elif [[ $REPLY = 2 ]] ; then
  ip link set enp0s25 up
  dhclient -4 enp0s25
else 
  printf '%s\n' "Please answer 1 or 2"
fi
}

f_do_KeyboardSetup(){ # U-IO -> IO
    ls /run/current-system/profile/share/keymaps/i386/qwerty/
    read -p "Please enter you preferred keyboard layout, exclude the .map.gz part: " keys
    loadkeys "$keys"
}
f_do_Partitioning(){ # U-IO -> IO
    read -p "${targetdev} headers will now be erased, please press enter to continue" key
    wipefs --all "${targetdev}"
    head -c 3145728 /dev/urandom > "$targetdev"; sync # this somehow solved an issue with kernel panic in qemu virtualization
    read -p "The automated partitioning will now start. Press enter to continue" key
    # cfdisk
    parted --script "$targetdev" mklabel gpt \
      mkpart primary 1MiB 3MiB \
      mkpart primary 3MiB 100% \
      set 1 boot on \
      set 1 bios_grub on
}
f_do_Encrypt(){ # U-IO -> IO
    read -p "${targetdev}2 will now be luksencrypted, please press enter to continue" key
    cryptsetup luksFormat "${targetdev}"2    
    #cryptsetup -v --cipher serpent-xts-plain64 --key-size 512 --hash=whirlpool --iter-time 500 --use-random --verify-passphrase luksFormat "${targetdev}"2
}
f_do_MakeFilesystem(){ # -> IO
    mkfs.btrfs -f -L fs_root /dev/mapper/fs_root
    # subvolume stuff failed for unknown reason and needs to be retried
    #btrfs subvolume create /mnt/sv_root
    #umount /dev/mapper/fs_root
    #mount -o subvolid=257 /dev/mapper/fs_root /mnt
    #btrfs subvolume set-default 257 /mnt
    #btrfs filesystem show -m
}
f_do_InstallGuixSD(){ # -> IO
    cd
    sleep 1
    herd start cow-store /mnt
    sleep 1
    mkdir -p /mnt/etc
    cp working_config.scm /mnt/etc/config.scm
    #guix package -i beep
    guix pull
    guix system init /mnt/etc/config.scm /mnt --fallback
}
f_do_Decrypt(){
    cryptsetup luksOpen "${targetdev}"2 fs_root
}
f_do_Mount(){
    mount /dev/mapper/fs_root /mnt
}
f_do_Grub_Fix(){
    mkdir -p /mnt/boot/grub
    grub_path="$(find /mnt/gnu/store -name '*grub.cfg' -printf '%T+ %p\n' | sort -r | head -n 1 | awk ' { print $2 } ')"
    #grub_path="/mnt/gnu/store/$(ls -al /mnt/gnu/store | grep grub.cfg | awk ' { print $9 } ')"
    echo $grub_path
    cp "${grub_path}" /mnt/boot/grub/libreboot_grub.cfg
    # This should possibly be a bash-alias or a hook for guix system
    # reconfigure in the installed system so that libreboot can
    # reliably chainload the configfile /boot/libreboot_grub.cfg in
    # order to utilize GuixSD system versioning in the grub-menu.
}
main(){
    targetdev="/dev/sda"
    f_do_NetworkSetup
    f_do_KeyboardSetup
    f_do_Partitioning
    f_do_Encrypt
    f_do_Decrypt
    f_do_MakeFilesystem
    f_do_Mount
    f_do_InstallGuixSD
    #f_do_Grub_Fix
}
main

