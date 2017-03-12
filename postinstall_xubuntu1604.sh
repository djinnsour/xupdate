#!/bin/bash
#
# xupdate.sh version 0.8.3
# lun. 23 janv. 2017 11:50:08 CET
#
# POST INSTALLATION SCRIPT FOR XUBUNTU 16.04 LTS
# CREDITS: Internet
#
# ------------------------------------------------------------------------------
# INSTALLATION
# cd to the folder that contains this script (xupdate.sh)
# make the script executable with: chmod +x xupdate.sh
# then run sudo ./xupdate.sh
#
# ------------------------------------------------------------------------------
# Copyright 2017 Philip Wittamore http://www.wittamore.com
# GNU General Public License
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------------

# clear terminal
clear

# ------------------------------------------------------------------------------
# ERROR LOGGING SETUP
echo 'XUPDATE LOG' > xupdate.log

# ------------------------------------------------------------------------------
# text colour

GR='\033[1;32m'
RD='\033[1;31m'
BL='\033[1;34m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# only 16.04 LTS - guys, lts versions only so I can drink beer in between

RELEASE=$(lsb_release -s -r)
if [ ! "$RELEASE" == "16.04" ]; then
  echo -e "${RD}This script is for v16.04 LTS only, exiting.${NC}"
  exit 1
fi

# ------------------------------------------------------------------------------
# Make sure only root can run our script

if [ "$(id -u)" != "0" ]; then
 echo -e "${RD}This script must be run as root, exiting.${NC}"
 exit 1
fi

# ------------------------------------------------------------------------------
# TEST INTERNET CONNECTION

echo -e "${GR}Testing internet connection...${NC}"
wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ ! $? -eq 0 ]]; then
  echo -e "${RD}This script requires an internet connection, exiting.${NC}"
  exit 1
fi

# ------------------------------------------------------------------------------
# RAM TEST

MEM=$(free -g | grep "Mem:" | tr -s ' ' | cut -d ' ' -f2)
if ((MEM < 2)); then
  echo "${RD}Insufficient RAM, exiting.${NC}"
fi

# ------------------------------------------------------------------------------
# FIND USER AND GROUP THAT RAN su or sudo su

XUSER=$(logname)
XGROUP=$(id -ng "$XUSER")
DESKTOP=$(su - "$XUSER" -c 'xdg-user-dir DESKTOP')

# ------------------------------------------------------------------------------
# GET ARCHITECTURE

ARCH=$(uname -m)

# ------------------------------------------------------------------------------
# shut up installers

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# 
LAPTOP=$(laptop-detect; echo -e  $?)

# ------------------------------------------------------------------------------
# GET IP AND IS COUNTRY FRANCE

#IP=$(wget -qO- checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
#FR=$(wget -qO- "ipinfo.io/$IP" | grep -c '"country": "FR"')

# ------------------------------------------------------------------------------
# Installation functions
# use apt-get and not apt in shell scripts

xinstall () {
  echo -e "${BL}   installing $1 ${NC}"
  apt-get install -q -y "$1" >> xupdate.log 2>&1 || echo -e "${RD}$1 not installed${NC}"
}
xremove () {
  echo -e "${BL}   removing $1 ${NC}"
  apt-get purge -q -y "$1" >> xupdate.log 2>&1 || echo -e "${RD}$1 not removed${NC}"
}

# ------------------------------------------------------------------------------
# XPI functions for installing firefox extensions

EXTENSIONS_SYSTEM='/usr/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/'
#EXTENSIONS_USER=$(echo "/home/$XUSER/.mozilla/firefox/*.default/extensions/")

get_addon_id_from_xpi () { #path to .xpi file
  addon_id_line=$(unzip -p "$1" install.rdf | egrep '<em:id>' -m 1)
  addon_id=$(echo "$addon_id_line" | sed "s/.*>\(.*\)<.*/\1/")
  echo "$addon_id"
}

get_addon_name_from_xpi () { #path to .xpi file
  addon_name_line=$(unzip -p "$1" install.rdf | egrep '<em:name>' -m 1)
  addon_name=$(echo "$addon_name_line" | sed "s/.*>\(.*\)<.*/\1/")
  echo "$addon_name"
}

install_addon () {
  xpi="${PWD}/${1}"
  extensions_path=$2
  new_filename=$(get_addon_id_from_xpi "$xpi").xpi
  new_filepath="${extensions_path}${new_filename}"
  addon_name=$(get_addon_name_from_xpi "$xpi")
  if [ -f "$new_filepath" ]; then
    echo "File already exists: $new_filepath"
    echo "Skipping installation for addon $addon_name."
  else
    cp "$xpi" "$new_filepath"
  fi
}

# ------------------------------------------------------------------------------
# Spinner

spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while ps --pid "$pid" &>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ------------------------------------------------------------------------------
# START

echo -e "${GR}Starting Xubuntu 16.04 post-installation script.${NC}"
echo -e "${GR}Please be patient and don't exit until you see FINISHED.${NC}"

# ------------------------------------------------------------------------------
# ADD REQUIRED FOLDERS
mkdir -p "/home/$XUSER/.config/autostart"
mkdir -p "/home/$XUSER/.local/share/applications"

# ------------------------------------------------------------------------------
# ADD REPOSITORIES

echo -e "${GR}Adding repositories...${NC}"

# Libreoffice - latest version
echo -e "${BL}     Libreoffice repository...${NC}"
add-apt-repository ppa:libreoffice/ppa -y  >> xupdate.log 2>&1 & spinner $!

# Google Chrome (not supported on 32bit)
if [ "$ARCH" == "x86_64" ]; then
  echo -e "${BL}     Google repository...${NC}"
  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - & spinner $!
  echo "deb https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
fi

# Linrunner - supercedes laptop-tools and is indispensable on laptops
if [ "$LAPTOP" == "0" ]; then
echo -e "${BL}     Linrunner repository...${NC}"
add-apt-repository ppa:linrunner/tlp -y >> xupdate.log 2>&1 & spinner $!
fi

# ------------------------------------------------------------------------------
# REMOVE

echo -e "${GR}Removing files...${NC}"

# VLC does a better job
#xremove parole
# Shotwell viewer allows printing
#xremove ristretto

# ------------------------------------------------------------------------------
# UPDATE & UPGRADE

echo -e "${GR}Updating...${NC}"
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
echo -e "${GR}Upgrading...${NC}"
apt-get upgrade -q -y >> xupdate.log 2>&1 & spinner $!

# ------------------------------------------------------------------------------
# TWEAKS

echo -e "${GR}Tweaking the system...${NC}"

# ------------------------------------------------------------------------------
# Terminal Configuration

mkdir -p "/home/$XUSER/.config/xfce4/terminal"
cat <<EOF > "/home/$XUSER/.config/xfce4/terminal/terminalrc"
[Configuration]
ScrollingUnlimited=TRUE
EOF

# ------------------------------------------------------------------------------
# Enable ctrl+alt+backspace

sed -i "s/XKBOPTIONS=\x22\x22/XKBOPTIONS=\x22terminate:ctrl_alt_bksp\x22/g" /etc/default/keyboard

# ------------------------------------------------------------------------------
# VM Optimize

sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

FND=" /               ext4    errors=remount-ro 0"
RPL=" /               ext4    discard,noatimg,errors=remount-ro 0"
sed -i "s/$FND/$RPL/g" /etc/fstab

echo "vm.swappiness=1" > /etc/sysctl.d/99-swappiness.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf >> xupdate.log 2>&1 

# ------------------------------------------------------------------------------
#Fix stupid MDNS default configuration issue

FND="files mdns4_minimal [NOTFOUND=return] dns"
RPL=" files dns mdns4_minimal [NOTFOUND=return]"

# ------------------------------------------------------------------------------
# Enable unattended security upgrades

echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-updates.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-backports.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades

# ------------------------------------------------------------------------------
# Set update periods

rm /etc/apt/apt.conf.d/10periodic
cat <<EOF > /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
chmod 644 /etc/apt/apt.conf.d/10periodic

# ------------------------------------------------------------------------------
# Speed up gtk
{
echo "gtk-menu-popup-delay = 0" 
echo "gtk-menu-popdown-delay = 0"
echo "gtk-menu-bar-popup-delay = 0"
echo "gtk-enable-animations = 0"
echo "gtk-timeout-expand = 0"
echo "gtk-timeout-initial = 0"
echo "gtk-timeout-repeat = 0"
} > "/home/$XUSER/.gtkrc-2.0"

# ------------------------------------------------------------------------------
# Set the default QT style
echo "QT_STYLE_OVERRIDE=gtk+" >> /etc/environment

# ------------------------------------------------------------------------------
# INSTALL

echo -e "${GR}Package installation...${NC}"
echo -e "${GR}  Base...${NC}"

# ------------------------------------------------------------------------------
# Due to a bug in ttf-mscorefonts-installer, this package must be downloaded from Debian 
# and installed before the rest of the packages:
echo -e "${GR}  Fixing ttf-mscorefonts bug...${NC}"
xinstall cabextract
wget -q http://ftp.fr.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb >> xupdate.log 2>&1 & spinner $!
dpkg -i ttf-mscorefonts-installer_3.6_all.deb >> xupdate.log 2>&1 & spinner $!

# ------------------------------------------------------------------------------
# AppImages require FUSE to run. 
# Filesystem in Userspace (FUSE) is a system that lets non-root users mount filesystems.
echo -e "${GR}  Fuse...${NC}"
xinstall fuse
modprobe fuse
groupadd fuse
usermod -G fuse "$XUSER"

# ------------------------------------------------------------------------------
# Devilspie allows setting application wm defaults
echo -e "${GR}  Devilspie...${NC}"
xinstall devilspie
xinstall gdevilspie
mkdir -p "/home/$XUSER/.devilspie"
cat <<EOF > "/home/$XUSER/.config/autostart/devilspie.desktop"
[Desktop Entry]
Name=devilspie
Exec=/usr/bin/devilspie
Type=Application
X-GNOME-Autostart-enabled=true
EOF
chmod 644 "/home/$XUSER/.config/autostart/devilspie.desktop"

# ------------------------------------------------------------------------------

echo -e "${GR}  Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

# ------------------------------------------------------------------------------
# system tools

echo -e "${GR}  System tools...${NC}"

xinstall preload
xinstall lsb-core
xinstall curl 
xinstall ppa-purge 
xinstall gtk2-engines 
xinstall numlockx
xinstall inxi

# ------------------------------------------------------------------------------
# Compression

echo -e "${GR}  Compression tools...${NC}"

xinstall unace 
xinstall rar 
xinstall unrar 
xinstall p7zip-rar 
xinstall p7zip-full  
xinstall sharutils 
xinstall uudeview 
xinstall mpack 
xinstall arj 
xinstall file-roller 


# ------------------------------------------------------------------------------
# Printing

echo -e "${GR}  Printing...${NC}"

xinstall cups-pdf 

# ------------------------------------------------------------------------------
# ACCESSORIES

echo -e "${GR}  Accessories...${NC}"


# ------------------------------------------------------------------------------
# DESKTOP

echo -e "${GR}  Desktop...${NC}"


# ------------------------------------------------------------------------------
# GRAPHICS

echo -e "${GR}  Graphics...${NC}"

# ------------------------------------------------------------------------------
# AUDIO/VIDEO

echo -e "${GR}  Audio and Video...${NC}"


# ------------------------------------------------------------------------------
# OFFICE
# libreoffice - latest version from ppa

echo -e "${GR}  Office...${NC}"


# ------------------------------------------------------------------------------
# clean up

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

# ------------------------------------------------------------------------------
# SELECTED EXTRA APPLICATIONS

echo -e "${GR}Installing selected extra applications...${NC}"

# ------------------------------------------------------------------------------
# LOCAL FILES

# Install extra fonts
# requires a folder named "fonts" containing extra ttf fonts

if [ -d "fonts" ]; then
  echo -e "${GR}Installing TTF fonts from folder 'fonts'...${NC}"
  mkdir -p /usr/share/fonts/truetype/xttf
  cp -r fonts/*.ttf /usr/share/fonts/truetype/xttf 2>> /dev/null  & spinner $!
  chmod -R 755 /usr/share/fonts/truetype/xttf
  fc-cache -fv > /dev/null & spinner $!
fi

# ------------------------------------------------------------------------------
# FINISH

# ------------------------------------------------------------------------------
# update system icon cache

echo -e "${GR}Update icon cache...${NC}"
for d in /usr/share/icons/*; do gtk-update-icon-cache -f -q "$d" >> xupdate.log 2>&1; done 

# ------------------------------------------------------------------------------
# add default desktop launchers

echo "### Install desktop launchers." >> xupdate.log
echo -e "${GR}Install default desktop launchers...${NC}"
cp /usr/share/applications/firefox.desktop "$DESKTOP" 2>> xupdate.log
cp /usr/share/applications/libreoffice-startcenter.desktop "$DESKTOP" 2>> xupdate.log
chmod -f 775 "$DESKTOP/*.desktop"

echo -e "${GR}Cleaning up...${NC}"

{ 
apt-get install -f -y 
apt-get autoremove 
apt-get clean 
} >> xupdate.log 2>&1 & spinner $!

update-grub >> xupdate.log 2>&1

# safely correct permissions because we are working as root
chown -Rf "$XUSER:$XGROUP" "/home/$XUSER"
chown -Rf "$XUSER:$XGROUP" "/home/$XUSER/.[^.]*"

echo -e "${GR}Hardware information${NC}"

inxi -b

echo
/usr/games/cowsay "You dirty rotten swines, you! You have deaded me again!"
echo

echo -e "${GR}######## FINISHED ########${NC}"
echo
echo -e "${RD}Reboot now!${NC}"
echo





