#!/bin/bash
set -o nounset -o errexit

chroot() {
  # shellcheck disable=SC2016
  command chroot debian /bin/bash -c 'source /etc/profile; exec $0 "$@"' "$@"
}

debootstrap --variant=minbase bullseye debian https://deb.debian.org/debian/
chroot apt-get install -y systemd linux-image-amd64

cp files/init debian/
cp -r files/cri-o/* debian/
cp -r files/k8s/* debian/
cp -r files/mukube-configurator/* debian/
chroot apt-get update
chroot apt-get install -y cri-o cri-o-runc kubelet kubeadm kubectl
chroot rm /etc/machine-id /var/lib/dbus/machine-id
chroot ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
echo debian > debian/etc/hostname
chroot passwd -d root
chroot apt-get clean

cd debian
find . -not \( -name "vmlinuz*" -o -name "initrd.img*" \) | cpio -o --format=newc | zstd --long > ../initrd.img
cd ..

echo "console=ttyS0 rd.systemd.gpt_auto=no" > cmdline.txt
# https://www.freedesktop.org/software/systemd/man/systemd-stub.html
objcopy \
    --add-section .cmdline=cmdline.txt --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$(realpath debian/vmlinuz)" --change-section-vma .linux=0x2000000 \
    --add-section .initrd=./initrd.img --change-section-vma .initrd=0x3000000 \
    ./debian/usr/lib/systemd/boot/efi/linuxx64.efi.stub \
    debian.efi

rm -f debian.img
truncate -s "2G" "debian.img"
sgdisk --align-end \
  --clear \
  --new 0:0:+1G --typecode=0:ef00 \
  --new 0:0:0 --typecode=0:ef00 debian.img

mkfs.fat -v --offset 2048 debian.img $((1024*1024))
mmd -i debian.img@@$((2048*512)) ::/EFI ::/EFI/BOOT
mcopy -i debian.img@@$((2048*512)) debian.efi ::/EFI/BOOT/BOOTx64.EFI
