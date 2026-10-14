#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Install extra repos for kodi
dnf5 install -y \
     https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
     https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install Packages
dnf5 install -y \
     kodi \
     kodi-inputstream-adaptive \
     cage \
     libva-intel-driver \
     libva-utils \
     mesa-dri-drivers \
     mesa-va-drivers \
     pipewire \
     pipewire-pulseaudio \
     wireplumber \
     alsa-utils \
     podman \
     podman-compose \
     flatpak \
     cockpit \
     cockpit-files \
     cockpit-storaged \
     cockpit-networkmanager \
     cockpit-ostree \
     ffmpeg

# Enable kodi service
systemctl enable kodi.service bootc-fetch-apply-updates.timer

# Add flatpak repo
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

### Enable optional management services

systemctl enable podman.socket
systemctl enable cockpit.socket

