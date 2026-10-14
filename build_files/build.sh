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


# this installs a package from fedora repos
dnf5 install -y \
     mesa-dri-drivers \
     mesa-va-drivers \
     pipewire \
     wireplumber \
     ffmpeg \
     kodi \
     kodi-inputstream-adaptive \
     cockpit-system \
     cockpit-podman \
     cockpit-storaged \
     cockpit-networkmanager \
     cockpit-files \
     cockpit-ostree \
     cockpit
     samba \
     udev \
     podman-compose \
     && dnf clean all

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# Adding firewall rules
#firewall-offline-cmd --add-service=cockpit 
#firewall-offline-cmd --add-service=samba

# Setup SELinux rule
#semanage fcontext --add --type "samba_share_t" "/var/media(/.*)?"
#restorecon -R /var/media

#### Example for enabling a System Unit File
systemctl enable podman.socket
systemctl enable cockpit.socket
