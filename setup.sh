read -p "Enter disk name: " disk
read -p "Enter username: " username
read -s -p "Enter user password: " password
read -s -p "Enter root password: " rootPassword

reflector --latest 20 --sort rate --counter JP,SG,KR --save /etc/pacman.d/mirrorlist

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

