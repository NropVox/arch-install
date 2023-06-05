read -p "Enter disk name: " disk
read -p "Enter username: " username
read -s -p "Enter user password: " password
echo 
read -s -p "Enter root password: " rootPassword
echo

reflector --latest 20 --sort rate -c JP,SG,KR --save /etc/pacman.d/mirrorlist

device=/dev/${disk}
wipefs --all ${device}
sgdisk --clear "${device}" --new 1::-551MiB "${device}" --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"

part_root=${device}1
part_boot=${device}2

mkfs.vfat -n "EFI" -F 32 "${part_boot}"
mkfs.ext4 "${part_root}"

mkdir -p /mnt/boot

mount ${part_root} /mnt

pacstrap /mnt base linux linux-firmware git nano sudo grub efibootmgr

mount ${part_boot} /mnt/boot

genfstab -L /mnt >> /mnt/etc/fstab

cp post-install.sh /mnt/opt

## Setup users and password
useradd -m -R /mnt ${username}
echo "${username}:${password}" | chpasswd -R /mnt
echo "root:${rootPassword}" | chpasswd -R /mnt
echo "aj ALL=(ALL) ALL" > /mnt/etc/sudoers.d/00_aj

## Setup grub
arch-chroot /mnt mkdir boot/efi
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Archer --efi-directory=/boot/efi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo Install Complete make sure to run the /opt/post-install.sh on first boot