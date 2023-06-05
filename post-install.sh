## Setup locale
echo "en_US.UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

## Setup time and date
timedatectl set-ntp true
timedatectl --systohc --utc
timedatectl set-timezone Asia/Manila

## Setup grub
mkdir boot/efi
grub-install --target=x86_64-efi --bootloader-id=Archer --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

## Setup hostname
echo "archer" > /etc/hostname

## Setup users and password
useradd -m ${username}
echo "${username}:${password}" | chpasswd
echo "root:${rootPassword}" | chpasswd
echo "aj ALL=(ALL) ALL" > /etc/sudoers.d/00_aj

## Setup pacman config
pacman_conf=/etc/pacman.conf
sed 's/#ParallelDownloads/ParallelDownloads/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf
sed 's/#Colors/Colors/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf

## Install yay
yaypkg=/home/aj/.yay-pkg
sudo -u aj git clone https://aur.archlinux.org/yay-git.git ${yaypkg} && cd ${yaypkg} && makepkg -si
rm -rf ${yaypkg}

## Install Packages
# yay -S hyprland


## Final Touches
uuid=$(blkid | grep /dev/sdb1 | grep -oP '\sUUID="\K[\w-]+')
sudo mkdir -p /media/aj
sudo chown aj:aj /media/aj
sudo echo "
# /dev/sdb1
UUID=$uuid /media/aj ext4 defaults 0 2
" >> /etc/fstab
sudo mount -a

ln -s /media/aj/backup/android-os /home/aj
ln -s /media/aj/backup/scripts /home/aj
ln -s /media/aj/backup/Projects /home/aj