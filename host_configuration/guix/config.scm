;; This is an operating system configuration template
;; for a "desktop" setup with Xfce where the
;; root partition is encrypted with LUKS.

(use-modules 
	(gnu)
        (gnu system nss) ; nameservice switch
	(guix gexp)
	(guix store)
	(srfi srfi-1) ; for remove function
	(guix monads))
(use-service-modules 
	desktop 
	dbus 
	networking
	ssh)
(use-package-modules 
	certs vpn; https etc.
	gl ; for mesa and mesa-utils
	guile java gnuzilla ruby
	bash screen ssh shells 
	mtools pkg-config linux glib wget admin zip suckless disk version-control
        flashing-tools ; for flashrom to configure grub in libreboot.
	xorg xdisorg
	fonts fontutils pdf image-viewers ghostscript
	wm enlightenment gnome xfce
        emacs 
	libreoffice graphviz
	messaging ; for qtox and gajim
	gtk
	mpd
	video ; for mpv
	; databases web php for mariadb nginx and php respectively.
	qemu spice)

(operating-system
  (host-name "myhostname")
  (timezone "Europe/Stockholm")
  (locale "en_US.UTF-8")

  ;; Assuming /dev/sdX is the target hard disk, and "fs_root"
  ;; is the label of the target root file system.
  (bootloader (grub-configuration (device "/dev/sda")))

  ;; Specify a mapped device for the encrypted root partition.
  ;; The UUID is that returned by 'cryptsetup luksUUID'.
  (mapped-devices
   (list (mapped-device
          (source "/dev/sda1")
          (target "fs_root")
          (type luks-device-mapping))))

  (file-systems (cons (file-system
                        (device "/dev/mapper/fs_root")
                        (title 'device)
                        (mount-point "/")
                        (type "ext4")
                        (needed-for-boot? #t)
                        (dependencies mapped-devices))
                      %base-file-systems))

  (users (cons* (user-account
                (name "myuser")
                (comment "myuser")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video"
                                        "kvm"))
                (home-directory "/home/myuser"))
	        (user-account 
	        (name "user2")
		(comment "user2")
		(group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video"
                                        "kvm"))
                (home-directory "/home/user2"))		
               %base-user-accounts))

  ;; This is where we specify system-wide packages.
  (packages (cons* 
		nss-certs openvpn        ;for HTTPS access
		gvfs                     ;for user mounts
		zsh rxvt-unicode terminology screen mpv bash-completion; terminal and console 
		mtools fuse sshfs-fuse pkg-config glib btrfs-progs fuse-exfat exfat-utils util-linux mesa mesa-utils; mounting file-systems etc
                openssh htop wget net-tools unzip git flashrom; admin tools

		;; Fonts & Locale
                font-terminus gs-fonts font-gnu-freefont-ttf font-gnu-unifont font-dejavu font-bitstream-vera font-mutt-misc font-liberation
		font-util ftgl fontconfig
                glibc-locales glibc-utf8-locales ; locales

		;; Display server
                xorg-server xinit xauth xsensors xset setxkbmap xmodmap ; xorg display server related
		;xmonad ghc-xmonad-contrib arandr feh unclutter xdotool; xmonad window manager related
		;; Desktop environment
		;enlightenment 
		gtk+ gtkglext
		alsa-utils xfce4-pulseaudio-plugin

		;; Utilities
                emacs sed emacs-nginx-mode emacs-scheme-complete emacs-pdf-tools emacs-rudel emacs-wget emacs-lispy; text-editing
		libreoffice graphviz; office suite
		icecat icedtea ; browser, remember netsurf
		qtox gajim ; tox and xmpp
		mpd mpd-mpc ncmpcpp ; mpd music daemon and client
		
		
		;; Server stack
		; mariadb nginx php letsencrypt

		;; Virtualization
		qemu xf86-video-qxl xf86-video-fbdev spice
		%base-packages))

  ;; Using the "desktop" services includes 
  ;; the X11 log-in service, networking with Wicd, and more.
  (services (cons* 
		;(gnome-desktop-service)
		;(enlightenment-desktop-service)
                (xfce-desktop-service)
		(console-keymap-service "sv-latin1")
                ;(ntp-service) ; network time protocol
                ;(dbus-service) ; IPC or Inter-Process-Communication.
                ;(elogind-service)
                ;(polkit-service)
                ;(udisks-service)
                ;(slim-service) ; login screen
                ;(wicd-service) ; network

		;(dhcp-client-service)
		;(remove (lambda (service)
		;    (eq? (service-kind service) wicd-service-type))
		    %desktop-services )) ; desktop services provide lots of default services.

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
