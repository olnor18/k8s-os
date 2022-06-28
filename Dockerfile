FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y debootstrap binutils zstd cpio gdisk fdisk jq dosfstools mtools && \
    apt-get clean
