set -e

read -p "Enter disk name: " disk
read -p "Use btrfs? (y/N): " isbtrfs
read -p "Enter username: " username
read -s -p "Enter user password: " password
echo 
read -s -p "Enter root password: " rootPassword
echo

## Run reflector
echo Running reflector
reflector --latest 20 --sort rate -c JP,SG,KR --save /etc/pacman.d/mirrorlist

## Setup disk
device=/dev/${disk}
wipefs --all ${device}
sgdisk -f --clear "${device}" --new 1::-551MiB "${device}" --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"
part_root=${device}1
part_boot=${device}2
mkfs.vfat -n "EFI" -F 32 "${part_boot}"

if [[ ${isbtrfs} == "y" ]]; then
    echo btrfs
    mkfs.btrfs "${part_root}"
    mount ${part_root} /mnt

    btrfs subvolume create /mnt/@root
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots

    umount /mnt
    mount -o noatime,compress=lzo,space_cache,subvol=@root ${part_root} /mnt
    mkdir /mnt/{boot,var,home,.snapshots}
    mount -o noatime,compress=lzo,space_cache,subvol=@var ${part_root} /mnt/var
    mount -o noatime,compress=lzo,space_cache,subvol=@home ${part_root} /mnt/home
    mount -o noatime,compress=lzo,space_cache,subvol=@snapshots ${part_root} /mnt/.snapshots

else
    mkfs.ext4 "${part_root}"
    mount ${part_root} /mnt
fi


## Install Arch
pacstrap /mnt base linux linux-firmware git nano sudo grub efibootmgr networkmanager

## Setup fstab
mount ${part_boot} /mnt/boot/efi --mkdir
genfstab -L /mnt >> /mnt/etc/fstab

## Copy post install to new root
cp post-install.sh /mnt/opt

## Setup users and password
useradd -m -R /mnt ${username}
echo "${username}:${password}" | chpasswd -R /mnt
echo "root:${rootPassword}" | chpasswd -R /mnt
echo "aj ALL=(ALL) ALL" > /mnt/etc/sudoers.d/00_aj

## Setup grub
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Archer --efi-directory=/boot/efi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo Install Complete make sure to run the /opt/post-install.sh on first boot