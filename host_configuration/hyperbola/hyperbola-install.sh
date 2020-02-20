#!/bin/bash
# references: 
# open rc troubleshooting https://wiki.manjaro.org/index.php?title=OpenRC,_an_alternative_to_systemd#Troubleshooting
# installation guide: https://wiki.hyperbola.info/doku.php?id=en:installation_guide
# openRC install via manjaro: https://sourceforge.net/projects/manjaro-architect/files/
# ------------------------------------ #
# components / configuration files
# ------------------------------------ #

# DO THIS BY USING guix-script.sh

# crypttab
#
# fstab
#
# grub
#
# hostname
#
# hosts
#
# user
# useradd -aG sudo/wheel (correct for openrc groups)
# printf '%s\n' "Defaults targetpw" >> /etc/sudoers
# possibly uncomment %wheel or %sudo in /etc/sudoers
#
# Xorg keymaps
# reference1: https://wiki.archlinux.org/index.php/Keyboard_configuration_in_Xorg#Using_X_configuration_files
# reference2 (detailed): https://medium.com/@damko/a-simple-humble-but-comprehensive-guide-to-xkb-for-linux-6f1ad5e13450
# set in /etc/vconsole.conf and /etc/conf.d/keymaps
# find available keymaps with ''ls /usr/share/kbd/keymaps/i386/qwerty/'' and available models with ''cat /usr/share/X11/xkb/geometry/{use TAB and pick} | less'' then look for xkb_geometry "<model-name>"
#
# Xorg power settings: ref
#Section "ServerFlags"
  # disable low-level screensaver and screen DPMS poweroff
  #Option "BlankTime" "0"
  #Option "StandbyTime" "0"
  #Option "SuspendTime" "0"
  #Option "OffTime" "0"
#EndSection
# locales
#
# mkinitcpio
#
# openrc
#
# pacman, pacman-mirrors
#
# vconsole

# for Xorg, remember:
#   * dbus-uuidgen > /etc/machine-id
#   * xf86-input-mouse
#   * xf86-input-keyboard
#   * xf86-input-libinput-nosystemd libinput-nosystemd
#
# hostname again after migrating to parabola/hyperbola
#
# Kernels:
# linux-libre-lts linux-libre linux-libre-hardened
#
dd bs=512 count=4 if=/dev/urandom of=/crypto_keyfile.bin
printf '%s\n' "INCLUDE_FILES=/cryptkey" >> /etc/mkinitcpio.conf
cryptsetup luksAddKey "$TDEV" /crypto_keyfile.bin

/etc/mkinitcpio.conf or somewhere and then:
mkinitcpio -p linux-libre-lts etc.

# sshd didn't generate keys initially - fix by:
# pacman -S openssh
# ssh-keygen -A # below is deprecated
# for type in 'dsa' 'ecdsa' 'ed25519' 'rsa' ; do
#  ssh-keygen -t $type -f /etc/ssh/ssh_host_"${type}"_key
 # done
 #
# OPEN-RC SERVICES:
 # create /etc/init.d/sshd and rc-update add sshd default
 # list of ready-made services for inspiration:
 # https://github.com/andrewgregory/openrc-arch-services/tree/master/init.d
 # https://github.com/andrewgregory/openrc-arch-services/tree/master/conf.d
 # https://github.com/funtoo/openrc/tree/master/init.d.misc

