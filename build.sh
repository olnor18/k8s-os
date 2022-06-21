#!/bin/bash
set -o nounset -o errexit -o pipefail
readonly output="${PWD}/output"
readonly orig_pwd="${PWD}"
readonly tmpdir="$(mktemp --dry-run --directory --tmpdir="${PWD}/tmp")"
trap "rm -rf \"${tmpdir}\"" EXIT

chroot() {
  mv debian/etc/resolv.conf{,.org}
  cp -L /etc/resolv.conf debian/etc/resolv.conf
  # shellcheck disable=SC2016
  command chroot debian /bin/bash -c 'source /etc/profile; exec $0 "$@"' "$@"
  mv debian/etc/resolv.conf{.org,}
}

init() {
  mkdir -p "${output}" "${tmpdir}"
  if [[ -n ${SUDO_UID:-} ]] && [[ -n ${SUDO_GID:-} ]]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${output}" "tmp"
  fi
  cd "${tmpdir}"
}

bootstrap() {
  debootstrap --variant=minbase bullseye debian https://deb.debian.org/debian/
  chroot apt-get install -y systemd linux-image-amd64
}

k8s() {
  cp -r "${orig_pwd}/files/cri-o/"* debian/
  cp -r "${orig_pwd}/files/k8s/"* debian/
  chroot apt-get update
  chroot apt-get install -y cri-o cri-o-runc kubelet kubeadm kubectl
}

misc() {
  cp "${orig_pwd}/files/init" debian/
  cp -r "${orig_pwd}/files/mukube-configurator/"* debian/

  rm debian/{etc/machine-id,var/lib/dbus/machine-id}
  ln -sf /run/systemd/resolve/stub-resolv.conf debian/etc/resolv.conf
  echo debian > debian/etc/hostname
}

unified_kernel_image() {
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
}

image() {
  truncate -s "512M" "debian.img"
  sgdisk --clear \
    --new 0:0:+0 --typecode=0:ef00 \
    debian.img

  local json sector_size offset block_count
  json="$(sfdisk --json debian.img)"
  sector_size="$(jq .partitiontable.sectorsize <<< "${json}")"
  offset="$(jq .partitiontable.partitions[0].start <<< "${json}")"
  block_count="$(jq .partitiontable.partitions[0].size <<< "${json}")"
  block_count="$((block_count*sector_size/1024))"

  mkfs.fat --offset "${offset}" debian.img "${block_count}"
  mmd -i debian.img@@$((offset*sector_size)) ::/EFI ::/EFI/BOOT
  mcopy -i debian.img@@$((offset*sector_size)) debian.efi ::/EFI/BOOT/BOOTx64.EFI
}

prod() {
  true
}

dev() {
  chroot passwd -d root
  chroot apt-get install -y nano tmux htop
}

main() {
  if (( EUID != 0 )); then
    echo "Please run as root"
    exit 1
  fi

  init
  bootstrap
  k8s
  misc

  for image_type in {prod,dev}; do
    cp -ar debian{,.copy}
    ${image_type}
    chroot apt-get clean

    unified_kernel_image
    image
    mv debian.efi "${output}/k8s-os-${image_type}.efi"
    mv debian.img "${output}/k8s-os-${image_type}.img"
    if [[ -n ${SUDO_UID:-} ]] && [[ -n ${SUDO_GID:-} ]]; then
      chown "${SUDO_UID}:${SUDO_GID}" "${output}/k8s-os-${image_type}."{efi,img}
    fi

    rm -rf debian
    mv debian{.copy,}
  done
}

main
