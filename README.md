# k8s-os

k8s-os is a minimal stateless Debian image running solely in ram with k8s (`kubelet`, `kubeadm` and `kubectl`) and CRI-O preinstalled.

k8s-os must be used together with [mukube-configurator](https://github.com/distributed-technologies/mukube-configurator) for creating the k8s cluster.

## Testing with QEMU

The built images can be tested with QEMU like so:

Testing the EFI binary:
```sh
$ mkfs.ext4 -L config config.ext4 1M
$ qemu-system-x86_64 -machine accel=kvm:tcg -smp 4 -m 4096 -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd -kernel output/k8s-os-dev.efi -drive file=config.ext4,format=raw -monitor none -serial mon:stdio -nographic
```

Testing the image:
```sh
$ mkfs.ext4 -L config config.ext4 1M
$ qemu-system-x86_64 -machine accel=kvm:tcg -smp 4 -m 4096 -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd -drive file=output/k8s-os-dev.img,format=raw -drive file=config.ext4,format=raw -monitor none -serial mon:stdio -nographic
```

Please use `/usr/share/OVMF/OVMF_CODE.fd` as `-bios` on Debian-based distributions.

## Updating k8s/CRI-O

If updating k8s/CRI-O is desired, the newest documentation for updating Debian-based distributions must be followed.

Files required by k8s and CRI-O must be dropped in [`files/k8s/`](files/k8s/) and [`files/cri-o/`](files/cri-o/) respectively and the `k8s` function in `build.sh` must be tweaked if needed.

For k8s/CRI-O v1.24 the following documentation was followed:
* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl (please use this [link](https://v1-24.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl) when k8s v1.25 has been released)
* https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic (please use this [link](https://v1-24.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic) when k8s v1.25 has been released)
* https://github.com/cri-o/cri-o/blob/v1.24.0/install.md#apt-based-operating-systems
