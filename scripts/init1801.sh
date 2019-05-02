#!/bin/sh -x
#

# Detect primary root drive
if [ -e /dev/xvda ]; then
  drive=xvda
elif [ -e /dev/vda ]; then
  drive=vda
elif [ -e /dev/sda ]; then
  drive=sda
elif [ -e /dev/nvme0n1 ]; then
  drive=nvme0n1
fi

yum -y remove hwdata linux-firmware dracut-config-rescue NetworkManager aic94xx-firmware alsa-firmware alsa-lib alsa-tools-firmware biosdevname iprutils ivtv-firmware iwl100-firmware iwl1000-firmware iwl105-firmware iwl135-firmware iwl2000-firmware iwl2030-firmware iwl3160-firmware iwl3945-firmware iwl4965-firmware iwl5000-firmware iwl5150-firmware iwl6000-firmware iwl6000g2a-firmware iwl6000g2b-firmware iwl6050-firmware iwl7260-firmware libertas-sd8686-firmware libertas-sd8787-firmware libertas-usb8388-firmware plymouth --setopt="clean_requirements_on_remove=1"

# Install basic set of packages
yum -y install @core bzip2 lvm2 epel-release
yum -y install device-mapper-persistent-data yum-utils authconfig audit deltarpm chrony cloud-init cloud-utils cloud-utils-growpart dracut-config-generic dracut-norescue sudo curl tuned
yum -y update
yum -y install aria2 

# Force install of various Xen/AWS specific drivers into the kernel
sed -i 's/^#hostonly.*$/hostonly="no"/' /etc/dracut.conf
dracut --force --add-drivers "xen_blkfront virtio ixgbevf nvme" /boot/initramfs-$(uname -r).img

# disable firstboot
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# Set tuned profile to virtual-guest for use in AWS/virt
systemctl enable tuned
echo "virtual-guest" > /etc/tuned/active_profile
tuned-adm profile virtual-guest

# disable AutoVT services for TTYs
sed -i -r 's@^#NAutoVTs=.*@NAutoVTs=0@' /etc/systemd/logind.conf

# enable user namespacing
/sbin/grubby --args="namespace.unpriv_enable=1 user_namespace.enable=1" --update-kernel="$(/sbin/grubby --default-kernel)"
echo "user.max_user_namespaces=15076" >> /etc/sysctl.conf

# useless
systemctl disable kdump
systemctl disable rpcbind

# remove tty requirement
sed -i -e 's~\(.*\) requiretty$~#\1requiretty~' /etc/sudoers

# growfs
growpart -v /dev/$drive 1
xfs_growfs /

sync
