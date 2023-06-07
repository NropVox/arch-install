set -e

## Setup NetworkManager
systemctl enable NetworkManager
systemctl start NetworkManager

## Setup WiFi
read -p "Connect to wifi SSID: " ssid
read -p "Wifi Password: " wifiPassword

nmcli d wifi connect ${ssid} password ${wifiPassword}

## Get Info
read -p "Set this up as a server (y/N): " isserver

## Setup locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

## Setup time and date
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

## Setup hostname
echo "archer" > /etc/hostname

## Setup pacman config
pacman_conf=/etc/pacman.conf
sed 's/#ParallelDownloads/ParallelDownloads/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf
sed 's/#Color/Color/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf

## Install yay
yaypkg=/home/aj/.yay-pkg
sudo -u aj git clone https://aur.archlinux.org/yay-git.git ${yaypkg} && cd ${yaypkg} && sudo -u aj makepkg -si --noconfirm
rm -rf ${yaypkg}

packages=""
## Install Packages
if [[ ${isserver} == "y"  ]]; then
    packages="${packages} go nodejs npm pagekite"
else
    packages="${packages} hyprland-git"
fi

yay --noconfirm -S ${packages}

## Final Touches
if [[ -b /dev/sdb1 ]]; then
    mkdir -p /media/aj
    chown aj:aj /media/aj
    echo "
    # /dev/sdb1
    /dev/sdb1 /media/aj ext4 defaults 0 2
    " >> /etc/fstab
    systemctl daemon-reload
    mount -a

    sudo -u aj ln -s /media/aj/backup/{Android-OS,Documents,Dwnloads,Projects} /home/aj
fi

## Remove itself
rm /opt/post-install.sh
reboot