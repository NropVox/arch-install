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
sudo -u aj git clone https://aur.archlinux.org/yay-git.git ${yaypkg} && cd ${yaypkg} && sudo -u aj makepkg -si
rm -rf ${yaypkg}

## Install Packages
# yay -S hyprland


## Final Touches
uuid=$(blkid | grep /dev/sdb1 | grep -oP '\sUUID="\K[\w-]+')
mkdir -p /media/aj
chown aj:aj /media/aj
echo "
# /dev/sdb1
UUID=$uuid /media/aj ext4 defaults 0 2
" >> /etc/fstab
mount -a

ln -s /media/aj/backup/Android-OS /home/aj
ln -s /media/aj/backup/Documents /home/aj
ln -s /media/aj/backup/Downloads /home/aj
ln -s /media/aj/backup/Projects /home/aj

## Remove itself
rm /opt/post-install.sh