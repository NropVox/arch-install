set -e

read -p "Enter disk name: " disk
read -p "Use btrfs? (y/N): " isbtrfs
read -p "Encrypt disk? (y/N): " isencrypt
read -p "Enter username: " username

while : ; do
    read -s -p "Enter user password: " password
    echo
    read -s -p "Enter user password again: " password2
    echo 
    [[ $password != $password2 ]] || break
    echo "error try again"
done

while : ; do
    echo 
    read -s -p "Enter root password: " rootPassword
    echo
    read -s -p "Enter root password: " rootPassword2
    echo
    [[ $rootPassword != $rootPassword2 ]] || break
    echo "error try again"
done

clear

## Setup pacman config
pacman_conf=/etc/pacman.conf
sed 's/#ParallelDownloads/ParallelDownloads/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf
sed 's/#Color/Color/' $pacman_conf > $pacman_conf.tmp
mv $pacman_conf $pacman_conf.bak
mv $pacman_conf.tmp $pacman_conf

## Configure Mirrors
echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://arch.mirror.constant.com/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://arch.hu.fo/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

## Setup disk
device=/dev/${disk}
wipefs --all ${device}
sgdisk --clear "${device}" --new 1::-551MiB "${device}" --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"
part_root=${device}1
part_boot=${device}2
mkfs.vfat -n "EFI" -F 32 "${part_boot}"

part_root_install=${part_root}

if [[ ${isencrypt} == "y" ]]; then
    echo -n ${password} | cryptsetup luksFormat --type luks2 --label luks "${part_root}"
    echo -n ${password} | cryptsetup luksOpen "${part_root}" luks
    part_root_install=/dev/mapper/luks
fi

if [[ ${isbtrfs} == "y" ]]; then
    mkfs.btrfs -fL btrfs ${part_root_install}
    mount ${part_root_install} /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots

    umount /mnt
    mount -o noatime,nodiratime,compress=zstd,subvol=@ ${part_root_install} /mnt
    mkdir /mnt/{var,home,.snapshots}
    mount -o noatime,nodiratime,compress=zstd,subvol=@var ${part_root_install} /mnt/var
    mount -o noatime,nodiratime,compress=zstd,subvol=@home ${part_root_install} /mnt/home
    mount -o noatime,nodiratime,compress=zstd,subvol=@snapshots ${part_root_install} /mnt/.snapshots

    pacstrap /mnt btrfs-progs
    # mount ${part_boot} /mnt/boot --mkdir
else
    mkfs.ext4 "${part_root}"
    mount ${part_root} /mnt
    # mount ${part_boot} /mnt/boot/efi --mkdir
fi


## Install Arch
pacstrap /mnt base linux linux-firmware git nano sudo grub efibootmgr networkmanager intel-ucode base-devel

## Setup fstab
genfstab -L /mnt >> /mnt/etc/fstab

## Copy post install to new root
cp post-install.sh /mnt/opt
cp /etc/pacman.conf /mnt/etc/pacman.conf -f

## Setup users and password
useradd -m -R /mnt ${username}
echo -n "${username}:${password}" | chpasswd -R /mnt
echo -n "root:${rootPassword}" | chpasswd -R /mnt
echo "aj ALL=(ALL) ALL" > /mnt/etc/sudoers.d/00_aj

efi_dir="/boot"
## Setup grub
if [[ ${isencrypt} == "y" ]]; then
## Setup initramfs
cat << EOF > /mnt/etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems keyboard fsck)
EOF
    mount ${part_boot} /mnt${efi_dir}
    arch-chroot /mnt mkinitcpio -p linux
    device_uuid=$(blkid | grep ${part_root} | grep -oP ' UUID="\K[\w\d-]+')
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    perl -pi -e "s~GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\K~ cryptdevice=UUID=${device_uuid}:luks root=${part_root_install}~" /mnt/etc/default/grub
else
    efi_dir="${efi_dir}/efi"
    mount ${part_boot} /mnt${efi_dir} --mkdir
fi

arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=Archer --efi-directory=${efi_dir}
perl -pi -e "s/GRUB_TIMEOUT=\K\d+/0/" /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo Install Complete make sure to run the /opt/post-install.sh as root on first boot