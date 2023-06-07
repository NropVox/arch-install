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
sgdisk --clear "${device}" --new 1::-551MiB "${device}" --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"
part_root=${device}1
part_boot=${device}2
mkfs.vfat -n "EFI" -F 32 "${part_boot}"

if [[ ${isbtrfs} == "y" ]]; then
    echo -n ${password} | cryptsetup luksFormat --type luks2 --label luks "${part_root}"
    echo -n ${password} | cryptsetup luksOpen "${part_root}" luks

    luks_part=/dev/mapper/luks

    mkfs.btrfs -L btrfs ${luks_part}
    mount ${luks_part} /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots

    umount /mnt
    mount -o noatime,nodiratime,compress=zstd,subvol=@ ${luks_part} /mnt
    mkdir /mnt/{boot,var,home,.snapshots}
    mount -o noatime,nodiratime,compress=zstd,subvol=@var ${luks_part} /mnt/var
    mount -o noatime,nodiratime,compress=zstd,subvol=@home ${luks_part} /mnt/home
    mount -o noatime,nodiratime,compress=zstd,subvol=@snapshots ${luks_part} /mnt/.snapshots
    mount ${part_boot} /mnt/boot --mkdir
else
    mkfs.ext4 "${part_root}"
    mount ${part_root} /mnt
    mount ${part_boot} /mnt/boot/efi --mkdir
fi


## Install Arch
pacstrap /mnt base linux linux-firmware git nano sudo grub efibootmgr networkmanager intel-ucode base-devel

## Setup fstab
genfstab -L /mnt >> /mnt/etc/fstab

## Copy post install to new root
cp post-install.sh /mnt/opt

## Setup users and password
useradd -m -R /mnt ${username}
echo -n "${username}:${password}" | chpasswd -R /mnt
echo -n "root:${rootPassword}" | chpasswd -R /mnt
echo "aj ALL=(ALL) ALL" > /mnt/etc/sudoers.d/00_aj

efi_dir="/boot"
## Setup grub
if [[ ${isbtrfs} == "y" ]]; then
## Setup initramfs
cat << EOF > /mnt/etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems keyboard fsck)
EOF
    pacstrap /mnt btrfs-progs
    arch-chroot /mnt mkinitcpio -p linux
    device_uuid=$(blkid | grep ${part_root} | grep -oP ' UUID="\K[\w\d-]+')
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    perl -pi -e "s~GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\K~ cryptdevice=UUID=${device_uuid}:luks root=${luks_part}~" /mnt/etc/default/grub
    efi_dir="${efi_dir}/efi"
fi

arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Archer --efi-directory=${efi_dir}
perl -pi -e "s/GRUB_TIMEOUT=\K\d+/0/" /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo Install Complete make sure to run the /opt/post-install.sh on first boot