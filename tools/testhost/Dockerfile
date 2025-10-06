FROM jrei/systemd-ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
       openssh-server sudo python3 python3-apt python3-pip \
       iproute2 net-tools curl gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ansible \
    && mkdir -p /etc/sudoers.d \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && echo 'ansible:ansible' | chpasswd

RUN sed -i '/pam_nologin.so/d' /etc/pam.d/sshd

RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A
