set -e

username=$(whoami)

## Setup NetworkManager
systemctl enable --now NetworkManager

## Setup WiFi
read -p "Connect to wifi SSID: " ssid
read -p "Wifi Password: " wifiPassword

nmcli d wifi connect ${ssid} password ${wifiPassword}

## Get Info
# read -p "Set this up as a server (y/N): " isserver

## Setup locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

## Setup time and date
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

## Setup hostname
echo "archer" > /etc/hostname

## Install yay
yaypkg=/home/${username}/.yay-pkg
sudo -u ${username} git clone https://aur.archlinux.org/yay-git.git ${yaypkg} && cd ${yaypkg} && sudo -u ${username} makepkg -si --noconfirm
rm -rf ${yaypkg}

packages=""
## Install Packages
if [[ ${isserver} == "y"  ]]; then
    packages="${packages} go nodejs npm pagekite"
else
    packages="${packages} gdm gnome-shell gnome-terminal nautilus gnome-control-center gnome-system-monitor gvfs gvfs-mtp"
    packages="$packages gvfs-smb xdg-desktop-portal-gnome xdg-user-dirs-gtk gnome-tweaks"
fi

pacman --noconfirm -S ${packages}

## Final Touches
if [[ -b /dev/sdb1 ]]; then
    mkdir -p /mnt/${username}
    chown ${username}:${username} /mnt/${username}
    echo "
    # /dev/sdb1
    /dev/sdb1 /mnt/${username} ext4 defaults 0 2
    " >> /etc/fstab
    systemctl daemon-reload
    mount -a

    sudo -u ${username} ln -s /mnt/${username}/{Android-OS,Documents,Downloads,Pictures,Videos,Projects} /home/${username}
fi

## Remove itself
rm /opt/post-install.sh
reboot
