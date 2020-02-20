;; This is an operating system configuration template
;; for a "desktop" setup with GNOME and Xfce where the
;; root partition is encrypted with LUKS.

(use-modules (gnu) (gnu system nss) (guix build utils) (srfi srfi-1) (srfi srfi-26) (ice-9 ftw)) ; some extra modules occasionally needed for building stuff (when using --fallback)
(use-service-modules ssh networking xorg desktop) ; xorg added bcs of modifying slim-service
(use-package-modules certs gnome mtools linux glib mtools pkg-config gl flashing-tools) ; gnome for gvfs, gl for mesa

(operating-system
  (host-name "librelaptop")
  (timezone "Europe/Stockholm")
  (locale "en_US.UTF-8")

  ;; Assuming /dev/sdX is the target hard disk, and "my-root"
  ;; is the label of the target root file system.
  (bootloader (grub-configuration (device "/dev/sda")))
  (kernel-arguments '("iomem=relaxed")) ;; to use flashrom, see http://sprunge.us/IgCI
  ;; Specify a mapped device for the encrypted root partition.
  ;; The UUID is that returned by 'cryptsetup luksUUID'.
  (mapped-devices
   (list (mapped-device
          (source "/dev/sda2")
          (target "fs_root")
          (type luks-device-mapping))))

  (file-systems (cons (file-system
                        (device "/dev/mapper/fs_root")
                        (title 'device)
                        (mount-point "/")
                        (type "btrfs")
			(needed-for-boot? #t)
                        (dependencies mapped-devices))
                      %base-file-systems))

  (initrd (lambda (file-systems . rest)
            (apply base-initrd file-systems
                   #:extra-modules '("btrfs")
                   rest)))

  (users (cons (user-account
                (name "alice")
                (comment "alice")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video"))
                (home-directory "/home/alice"))
               %base-user-accounts))

  ;; This is where we specify system-wide packages.
  (packages (cons* nss-certs         ;for HTTPS access
                   gvfs              ;for user mounts
		   btrfs-progs ; util-linux mesa mesa-utils mtools fuse pkg-config fuse-exfat exfat-utils ntfs-3g sshfs-fuse
                   flashrom
                   %base-packages))

  ;; Add GNOME and/or Xfce---we can choose at the log-in
  ;; screen with F1.  Use the "desktop" services, which
  ;; include the X11 log-in service, networking with Wicd,
  ;; and more.
  (services (cons* (gnome-desktop-service)
                   ;(xfce-desktop-service)
                   (console-keymap-service "sv-latin1") ; to see available options type: ls /run/current-system/profile/share/keymaps/i386/qwerty/
                   ;%desktop-services)))
                   ; modifying for nvidia graphics using nouveau drivers.
                   %desktop-services)))


