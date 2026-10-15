# Kodi Atomic

This repo is a hobby project to try to make a atomic distro that runs Kodi.

It is built to run on my media pc in the living room.

## Building ISO:

I reccomend building on a existing ublue install (Bazzite, Aurora, etc).

Clone Repo and enter folder:

```
git clone https://github.com/lydiaperspective/kodi-atomic.git
cd kodi-atomic
```

#### Build Local Image:

```
sudo just build $target_image $tag
```

Once a image is built locally (use sudo podman images to check) build an iso.

```
sudo just build-iso localhost/kodi-atomic latest
```

Once the build finishes, it will output to /output/bootiso/. The ownership will be root so use command to change ownership to your user.

```
sudo chown -R $user:$user output/
```

Now you can flash the iso to a usb or run in virtual machine.

# Installing the OS:

During the installer make sure to create the user as **kodi**, you can set whatever password you want.

# Notes:

If the build tool leaves a folder owned by root in the project folder (it likely will) use the following command to remove it.

```
sudo rm -R folderName
```

## Goals:

- [x] Boot directly into Kodi.

- [ ] Add ability to install flatpaks and auto add to kodi interface.

- [ ] Add auto dvd ripper via podman container (using freemkv, dvdinfo and HandBrakeCLI for encoding).

## My Hardware:

- Intel i7-3770s

- 8GB DDR3

- 500GB HDD

- Intel Ethernet
