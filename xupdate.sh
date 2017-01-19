#!/bin/bash
#
# xupdate.sh version 0.8.1
# jeu. 19 janv. 2017 17:42:06 CET
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
# SELECT OPTIONAL PACKAGES

# install dialog if not available
apt-get install dialog >> xupdate.log 2>&1

cmd=(dialog --separate-output --checklist "Xupdate : Select optional packages" 20 70 10)

options=(1 "Skype - proprietary messaging application" off \
         2 "Wine - run windows apps (security risk)" off \
         3 "Franz - multi-client messaging application" off \
         4 "Google Earth - planetary viewer" off \
         5 "Krita - professional painting program" off \
         6 "Mega - 50Gb encrypted cloud storage" off \
         7 "Molotov - French TV viewer" off \
         8 "Pipelight - Silverlight plugin (security risk)" off \
         9 "Sublime Text - sophisticated text editor" off \
         10 "Numix theme - make your desktop beautiful" off \
         11 "Plank - MacOs-like desktop menu" off \
         12 "Ublock Origin - advert blocker for Firefox" off)

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
clear
echo -e "${BL}You have chosen these optional packages:"
for choice in $choices 
do
  case $choice in
    1)
    INSTSKYPE="1"
    echo -n "Skype, "
    ;;
    2)
    INSTWINE="1"
    echo -n "Wine, "
    ;;
    3)
    INSTFRANZ="1"
    echo -n "Franz, "
    ;;
    4)
    INSTGEARTH="1"
    echo -n "Google Earth, "
    ;;
    5)
    INSTKRITA="1"
    echo -n "Krita, "
    ;;
    6)
    INSTMEGA="1"
    echo -n "Mega Sync, "
    ;;
    7)
    INSTMOLOTOV="1"
    echo -n "Molotov, "
    ;;
    8)
    INSTWINE="1"
    INSTPIPELIGHT="1"
    echo -n "Pipelight, "
    ;;
    9)
    INSTSUBLIME="1"
    echo -n "Sublime Text, "
    ;;
    10)
    INSTNUMIX="1"
    echo -n "Numix Theme, "
    ;;
    11)
    INSTPLANK="1"
    echo -n "Plank, "
    ;;
    12)
    INSTUBLOCK="1"
    echo -n "Ublock Origin, "
    ;;
  esac
done
echo -e "...${NC}"

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

if [ "$INSTSKYPE" == "1" ]; then
# ubuntu partner (skype etc.)
echo -e "${BL}     Skype repository...${NC}"
add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner" -y >> xupdate.log 2>&1 & spinner $!
fi

if [ "$INSTNUMIX" == "1" ]; then
  echo -e "${BL}     Numix repository...${NC}"
  apt-add-repository ppa:numix/ppa -y >> xupdate.log 2>&1 & spinner $!
fi

if [ "$INSTWINE" == "1" ]; then
  echo -e "${BL}     Wine repository...${NC}"
  add-apt-repository ppa:wine/wine-builds -y >> xupdate.log 2>&1 & spinner $!
fi

if [ "$INSTPIPELIGHT" == "1" ]; then
  echo -e "${BL}     Pipelight repository...${NC}"
  add-apt-repository ppa:pipelight/stable -y >> xupdate.log 2>&1 & spinner $!
fi

if [ "$INSTSPOTIFY" == "1" ]; then
  echo -e "${BL}     Spotify repository...${NC}"
  gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv BBEBDCB318AD50EC6865090613B00F1FD2C19886 
  gpg --export --armor BBEBDCB318AD50EC6865090613B00F1FD2C19886 | apt-key add - 
  echo "deb http://repository.spotify.com stable non-free"  > /etc/apt/sources.list.d/spotify.list
fi

# ------------------------------------------------------------------------------
# REMOVE

echo -e "${GR}Removing files...${NC}"

# VLC does a better job
xremove parole
# Shotwell viewer allows printing
xremove ristretto

# ------------------------------------------------------------------------------
# UPDATE & UPGRADE

echo -e "${GR}Updating...${NC}"
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
echo -e "${GR}Upgrading...${NC}"
apt-get dist-upgrade -q -y >> xupdate.log 2>&1 & spinner $!

# ------------------------------------------------------------------------------
# TWEAKS

echo -e "${GR}Tweaking the system...${NC}"

# ------------------------------------------------------------------------------
# Bluetooth Pulseaudio module

BLUETOOTH=$(hcitool dev | grep -c hci0)
if [ "$BLUETOOTH" == "1" ]; then
  xinstall bluetooth >> xupdate.log 2>&1 & spinner $!
  xinstall pulseaudio-module-bluetooth >> xupdate.log 2>&1 & spinner $!
fi

# ------------------------------------------------------------------------------
# Enable terminal drop down 

xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/F12" \
	-s "xfce4-terminal --drop-down --hide-menubar --hide-borders --hide-toolbar" \
	--create --type string

# ------------------------------------------------------------------------------
# Terminal Configuration

mkdir -p "/home/$XUSER/.config/xfce4/terminal"
cat <<EOF > "/home/$XUSER/.config/xfce4/terminal/terminalrc"
[Configuration]
DropdownStatusIcon=FALSE
DropdownWidth=100
DropdownHeight=50
DropdownOpacity=90
DropdownAlwaysShowTabs=FALSE
FontName=DejaVu Sans Mono 10
ShortcutsNoMnemonics=TRUE
ShortcutsNoMenukey=TRUE
EOF

# ------------------------------------------------------------------------------
# Enable ctrl+alt+backspace

sed -i -e "s/XKBOPTIONS=\x22\x22/XKBOPTIONS=\x22terminate:ctrl_alt_bksp\x22/g" /etc/default/keyboard

# ------------------------------------------------------------------------------
# IF SSD

SSD=$(cat /sys/block/sda/queue/rotational)
if [ "$SSD" == "0" ]; then
  # preload
  if [ -f "/etc/preload.conf" ]; then
    sed -i -e "s/sortstrategy = 3/sortstrategy = 0/g" /etc/preload.conf
  fi
  # fstab - keep tmp folder and logs in ram (desktop only)
  {
  echo 'tmpfs /tmp     tmpfs defaults,noexec,nosuid,noatime,size=20% 0 0'
  echo 'tmpfs /var/log tmpfs defaults,noexec,nosuid,noatime,mode=0755,size=20% 0 0'
  echo ' ' 
  } >> /etc/fstab
  # fstrim is configured weekly by default
  # grub
  FIND="GRUB_CMDLINE_LINUX_DEFAULT=\x22quiet splash\x22"
  REPL="GRUB_CMDLINE_LINUX_DEFAULT=\x22elevator=deadline quiet splash\x22"
  sed -i "s/$FIND/$REPL/g" /etc/default/grub
  update-grub >> xupdate.log 2>&1
fi

# ------------------------------------------------------------------------------
# cache for symbol tables. Qt / GTK programs will start a bit quicker and consume less memory
# http://vasilisc.com/speedup_ubuntu_eng#compose_cache

mkdir -p "/home/$XUSER/.compose-cache"

# ------------------------------------------------------------------------------
# Get rid of “Sorry, Ubuntu xx has experienced internal error”

sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# ------------------------------------------------------------------------------
# Memory management

if [ "$SSD" == "0" ]; then
  echo "vm.swappiness=1" > /etc/sysctl.d/99-swappiness.conf
else
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
fi
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf >> xupdate.log 2>&1 

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
# Manage Laptop battery & overheating 

if [ "$LAPTOP" == "0" ]; then
  xinstall tlp 
  xinstall tlp-rdw 
  # THINKPAD ONLY
  VENDOR=$(cat /sys/devices/virtual/dmi/id/chassis_vendor)
  if [ "$VENDOR" == "LENOVO" ]; then
    xinstall tp-smapi-dkms 
    xinstall acpi-call-dkms 
  fi
  {
  tlp start
  systemctl enable tlp
  systemctl enable tlp-sleep
  } >> xupdate.log 2>&1
  # disable touchpad tapping and scrolling while typing
cat <<EOF > "/home/$XUSER/.config/autostart/syndaemon.desktop"
[Desktop Entry]
Name=Syndaemon
Exec=/usr/bin/syndaemon -i 1.0 -K -R -t
Type=Application
X-GNOME-Autostart-enabled=true
EOF
chmod 644 "/home/$XUSER/.config/autostart/syndaemon.desktop"
fi

# ------------------------------------------------------------------------------
# Wifi power control off for faster wifi at a slight cost of battery

WIFI=$(lspci | egrep -c -i 'wifi|wlan|wireless')
if [ "$WIFI" == "1" ];
  then
  WIFINAME=$(iwgetid | cut -d ' ' -f 1)
  echo '#!/bin/sh' >  /etc/pm/power.d/wireless
  echo "/sbin/iwconfig $WIFINAME power off" >> /etc/pm/power.d/wireless
  chmod 755 /etc/pm/power.d/wireless
fi

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
# override rhythmbox parole

sed -i -e "s/rhythmbox.desktop/vlc.desktop/g" /usr/share/applications/defaults.list
sed -i -e "s/parole.desktop/vlc.desktop/g" /usr/share/applications/defaults.list

# ------------------------------------------------------------------------------
# auto run inserted DVD's & CD's with VLC, and import photo's

xfconf-query -c thunar-volman -p /autoplay-audio-cds/command -n -t string -s "vlc cdda:///dev/sr0"
xfconf-query -c thunar-volman -p /autoplay-video-cds/command -n -t string -s "vlc dvd:///dev/sr0"
xfconf-query -c thunar-volman -p /autophoto/command -n -t string -s "shotwell"

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
echo -e "${GR}  Applications with restricted copyright...${NC}"
xinstall xubuntu-restricted-extras
ubuntu-drivers autoinstall >> xupdate.log 2>&1 & spinner $!

# ------------------------------------------------------------------------------
# libdvdcss
echo -e "${GR}  Libdvdcss...${NC}"
xinstall libdvd-pkg
dpkg-reconfigure libdvd-pkg >> xupdate.log 2>&1 & spinner $!

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
# Tool for enabling write support on NTFS disks
echo -e "${GR}  NTFS Config...${NC}"
xinstall ntfs-config 
if [ ! -d /etc/hal/fdi/policy ]; then
  mkdir -p /etc/hal/fdi/policy
fi

# ------------------------------------------------------------------------------
# Conky
wget -qP "/home/$XUSER" "http://www.wittamore.com/xupdate/.conkyrc" & spinner $!
mkdir -p /usr/share/fonts/truetype/conky
wget -qP /usr/share/fonts/truetype/conky http://www.wittamore.com/xupdate/ge-inspira.ttf & spinner $!
chmod -R 755 /usr/share/fonts/truetype/conky
fc-cache -fv > /dev/null & spinner $!
xinstall conky
cat <<EOF > "/home/$XUSER/.config/autostart/conky.desktop"
[Desktop Entry]
Name=Conky
Exec=conky -d -p 10
Type=Application
X-GNOME-Autostart-enabled=true
EOF

# ------------------------------------------------------------------------------

echo -e "${GR}  Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

# ------------------------------------------------------------------------------
# system tools

echo -e "${GR}  System tools...${NC}"

xinstall preload
xinstall lsb-core
xinstall joe 
xinstall mc 
xinstall curl 
xinstall gparted
xinstall gpart
xinstall ppa-purge 
xinstall synaptic 
xinstall gdebi 
xinstall gksu 
xinstall psensor 
xinstall fancontrol 
xinstall indicator-cpufreq 
xinstall smartmontools 
xinstall gsmartcontrol 
xinstall gnome-search-tool
xinstall gnome-disk-utility
xinstall searchmonkey
xinstall bleachbit 
xinstall gtk2-engines 
xinstall numlockx
xinstall deja-dup
xinstall inxi
xinstall keepassx
xinstall cowsay

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
xinstall hplip-gui 

# ------------------------------------------------------------------------------
# ACCESSORIES

echo -e "${GR}  Accessories...${NC}"

xinstall gedit 
xinstall gedit-plugins 
xinstall gedit-developer-plugins  
xinstall deja-dup 
xinstall xpdf
xinstall rednotebook 
xinstall calibre 
xinstall scribus 
xinstall brasero 
xinstall typecatcher 
xinstall geany 
xinstall geany-plugin* 

# ------------------------------------------------------------------------------
# DESKTOP

echo -e "${GR}  Desktop...${NC}"


# ------------------------------------------------------------------------------
# GRAPHICS

echo -e "${GR}  Graphics...${NC}"

xinstall gimp 
xinstall gimp-gmic 
xinstall gmic 
xinstall gimp-plugin-registry 
xinstall gimp-resynthesizer 
xinstall gimp-data-extras 
xinstall pandora 
xinstall pinta 
xinstall photoprint 

xinstall shotwell
# Shotwell viewer replaces ristretto as it allows printing
# supports JPEG, PNG, TIFF, BMP and RAW photo files as well as video files
xdg-mime default shotwell-viewer.desktop image/jpeg
xdg-mime default shotwell-viewer.desktop image/png
xdg-mime default shotwell-viewer.desktop image/tiff
xdg-mime default shotwell-viewer.desktop image/bmp
xdg-mime default shotwell-viewer.desktop image/raw

xinstall openshot 
xinstall dia-gnome 
xinstall inkscape 
xinstall blender 
xinstall blender-data 
xinstall glabels

# ------------------------------------------------------------------------------
# AUDIO/VIDEO

echo -e "${GR}  Audio and Video...${NC}"

xinstall vlc 
xinstall handbrake
xinstall devede 
xinstall audacity 
xinstall lame  
xinstall cheese 
xinstall mplayer 
xinstall gnome-mplayer 
xinstall kazam

# ------------------------------------------------------------------------------
# OFFICE
# libreoffice - latest version from ppa

echo -e "${GR}  Office...${NC}"

xinstall pdfchain

xinstall libreoffice 
xinstall libreoffice-pdfimport
xinstall libreoffice-nlpsolver
xinstall libreoffice-gtk

if [ "$LANGUAGE" == "fr_FR" ]; then
  xinstall libreoffice-l10n-fr 
  xinstall libreoffice-help-fr 
  xinstall hyphen-fr 
  # get the latest version by parsing telecharger.php
  wget -q "http://www.dicollecte.org/grammalecte/telecharger.php" & spinner $!
  GOXTURL=$(grep "http://www.dicollecte.org/grammalecte/oxt/Grammalecte-fr" < telecharger.php | cut -f4 -d '"')
  GOXT=G$(echo "$GOXTURL" | cut -f2 -d 'G')
  wget -q "$GOXTURL"  & spinner $!
  unopkg add --shared -f "$GOXT"
fi

# ------------------------------------------------------------------------------
# GAMES

echo -e "${GR}  Games...${NC}"

xinstall frozen-bubble 
xinstall pysolfc 
xinstall mahjongg 
xinstall aisleriot 
xinstall pingus 

# ------------------------------------------------------------------------------
# EDUCATION

echo -e "${GR}  Education...${NC}"

xinstall stellarium

# ------------------------------------------------------------------------------
# INTERNET

echo -e "${GR}  Internet...${NC}"

xinstall deluge-torrent
xinstall filezilla  

if [ "$ARCH" == "x86_64" ]; then
  xinstall google-chrome-stable 
fi

# ------------------------------------------------------------------------------
# clean up

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

# ------------------------------------------------------------------------------
# SELECTED EXTRA APPLICATIONS

echo -e "${GR}Installing selected extra applications...${NC}"

# ------------------------------------------------------------------------------
# PLANK

if [ "$INSTPLANK" == "1" ]; then
xinstall plank
# add autostart
cat <<EOF > /home/$XUSER/.config/autostart/plank.desktop
[Desktop Entry]
Name=Plank
Exec=/usr/bin/plank
Type=Application
X-GNOME-Autostart-enabled=true
EOF
chmod 644 "/home/$XUSER/.config/autostart/plank.desktop"
# add plank settings to menu
cat <<EOF > "/home/$XUSER/.local/share/applications/plank-preferences.desktop"
[Desktop Entry]
Name=Plank préférences
Comment=Préférences du dock plank
Exec=plank --preferences
Icon=plank
Terminal=false
Type=Application
Categories=Settings;
StartupNotify=false
EOF
chmod 644 "/home/$XUSER/.local/share/applications/plank-preferences.desktop"
fi

# ------------------------------------------------------------------------------
# WINE 

if [ "$INSTWINE" == "1" ]; then 
apt-get install -y -q --install-recommends wine-staging >> xupdate.log 2>&1 & spinner $!
xinstall winehq-staging
groupadd wine >> xupdate.log 2>&1
adduser "$XUSER" wine >> xupdate.log 2>&1
fi

# ------------------------------------------------------------------------------
# Skype

if [ "$INSTSKYPE" == "1" ]; then
  xinstall skype
fi

# ------------------------------------------------------------------------------
# Spotify

if [ "$INSTSPOTIFY" == "1" ]; then
  xinstall spotify-client
fi

# ------------------------------------------------------------------------------
# Google Earth

if [ "$INSTGEARTH" == "1" ]; then
  echo "   installing Google Earth"
  if [ "$ARCH" == "x86_64" ]; then
    xinstall libfontconfig1:i386 
    xinstall libx11-6:i386 
    xinstall libxrender1:i386 
    xinstall libxext6:i386 
    xinstall libgl1-mesa-glx:i386 
    xinstall libglu1-mesa:i386 
    xinstall libglib2.0-0:i386 
    xinstall libsm6:i386
    wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb >> xupdate.log 2>&1 & spinner $!
    dpkg -i google-earth-stable_current_amd64.deb >> xupdate.log 2>&1 & spinner $!
  else
    wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_i386.deb >> xupdate.log 2>&1 & spinner $!
    dpkg -i google-earth-stable_current_i386.deb >> xupdate.log 2>&1 & spinner $!
  fi
fi

# ------------------------------------------------------------------------------
# Krita

if [ "$ARCH" == "x86_64" ] && [ "$INSTKRITA" == "1" ]; then
  echo "   installing Krita"
  mkdir -p /opt/krita
  wget -qP /opt/krita http://download.kde.org/stable/krita/3.1.1/krita-3.1.1-x86_64.appimage  & spinner $!
  chmod a+x /opt/krita/*.appimage
  # add icon
  wget -qP /opt/krita http://www.wittamore.com/images/krita-icon.png & spinner $!
  # add desktop entry
cat <<EOF > /usr/share/applications/krita.desktop
[Desktop Entry]
Type=Application
Name=Krita
Comment=Krita is a free painting app
Exec=/opt/krita/krita-3.1.1-x86_64.appimage
Icon=/opt/krita/krita-icon.png
Categories=Graphics;2DGraphics;
EOF
fi

# ------------------------------------------------------------------------------
# Numix

if [ "$INSTNUMIX" == "1" ]; then
  echo "   installing Numix theme"
  xinstall numix-*
  xfconf-query -c xsettings -p /Net/ThemeName -s "Numix"
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Numix Circle"
fi

# ------------------------------------------------------------------------------
# Sublime Text 3

if [ "$INSTSUBLIME" == "1" ]; then
  echo "   installing Sublime Text"
  if [ "$ARCH" == "x86_64" ]; then
    wget -q /opt/sublime https://download.sublimetext.com/sublime-text_build-3126_amd64.deb & spinner $!
    dpkg -i sublime-text_build-3126_amd64.deb >> xupdate.log 2>&1 & spinner $!
  else
    https://download.sublimetext.com/sublime-text_build-3126_i386.deb & spinner $!
    dpkg -i sublime-text_build-3126_i386.deb >> xupdate.log 2>&1 & spinner $!
  fi
fi

# ------------------------------------------------------------------------------
# Enable silverlight plugin in firefox
# Pipelight development has been discontinued, as Firefox is
# retiring NPAPI support soon, and Silverlight is dead
# see http://pipelight.net/

if [ "$INSTPIPELIGHT" == "1" ]; then  
  echo "   installing Pipelight"
  apt-get install -y -q --install-recommends pipelight-multi >> xupdate.log 2>&1 & spinner $!
  chmod 777 /usr/lib/pipelight/
  chmod 666 /usr/lib/pipelight/*
  pipelight-plugin --update -y  >> xupdate.log 2>&1
  sudo -u "$XUSER" pipelight-plugin -y --create-mozilla-plugins | tee -a xupdate.log /dev/null
  sudo -u "$XUSER" pipelight-plugin -y --enable silverlight | tee -a xupdate.log /dev/null
fi

# ------------------------------------------------------------------------------
# Add Ublock Origin plugin to Firefox

if [ "$INSTUBLOCK" == "1" ]; then
  echo "   installing Ublock Origin Firefox plugin"
  echo -e "${RD}   NOTE: Plugin must be activated manually in Firefox${NC}"
  wget -q https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi >> xupdate.log 2>&1 & spinner $!
  install_addon addon-607454-latest.xpi "$EXTENSIONS_SYSTEM" >> xupdate.log 2>&1
fi

# ------------------------------------------------------------------------------
# FRANZ a free messaging app.
# Franz currently supports Slack, WhatsApp, WeChat, HipChat, Facebook Messenger, 
# Telegram, Google Hangouts, GroupMe, Skype and many more.

if [ "$INSTFRANZ" == "1" ]; then
  echo "   installing Franz"
# get latest version by parsing latest download page
mkdir -p /opt/franz
wget https://github.com/meetfranz/franz-app/releases/latest
if [ "$ARCH" == "x86_64" ]; then
  FRZ64=$( grep Franz-linux-x64 < latest | grep meetfranz | cut -f2 -d '"')
  wget -qO- "https://github.com$FRZ64" | tar zxf - -C /opt/franz/  & spinner $!
else
  FRZ32=$( grep Franz-linux-ia32 < latest | grep meetfranz | cut -f2 -d '"')
  wget -qO- "https://github.com/meetfranz$FRZ32" | tar zxf - -C /opt/franz/
fi
wget -q https://cdn-images-1.medium.com/max/360/1*v86tTomtFZIdqzMNpvwIZw.png -O /opt/franz/franz-icon.png 
# add desktop entry
cat <<EOF > /usr/share/applications/franz.desktop                                                                 
[Desktop Entry]
Type=Application
Name=Franz
Comment=Franz is a free messaging app 
Exec=/opt/franz/Franz
Icon=/opt/franz/franz-icon.png
Categories=Network;Messaging;
EOF
# autostart
cat <<EOF > /home/$XUSER/.config/autostart/franz.desktop                                                                 
[Desktop Entry]
Name=Franz
Exec=/opt/franz/Franz
Type=Application
X-GNOME-Autostart-enabled=true
EOF
chmod 644 "/home/$XUSER/.config/autostart/franz.desktop"
fi

# ------------------------------------------------------------------------------
# MOLOTOV French TV online viewer (only works in France)
# It is impossible to obtain the latest version number
# so it has to be manually added here. Grrr...

if [ "$INSTMOLOTOV" == "1" ]; then
  echo "   installing Molotov"
  # name of latest version
  MFILE='Molotov-1.1.2.AppImage'
  mkdir -p /opt/molotov
  xinstall libatk-adaptor 
  xinstall libgail-common 
  wget -qP "/opt/molotov" "https://desktop-auto-upgrade.s3.amazonaws.com/linux/$MFILE" & spinner $!
  if [ -f "/opt/molotov/$MFILE" ]; then
    chmod a+x "/opt/molotov/$MFILE"
  fi
  # launch molotov to install desktop entry
  sudo -u "$XUSER" "/opt/molotov/$MFILE" >> /dev/null 2>&1 &
fi

# ------------------------------------------------------------------------------
# CLOUD STORAGE
# MEGA: 50Gb, end to end encryption, GUI Linux client
# HUBIC: 25Gb, command line only
# PCLOUD: 10Gb, encryption is premium feature, native Linux client
# DROPBOX: 2Gb, GUI client but xubuntu integration needs work

if [ "$INSTMEGA" == "1" ]; then
  echo "   installing Mega"
  xinstall libc-ares2
  xinstall libcrypto++9v5
  if [ "$ARCH" == "x86_64" ]; then
    wget -q "https://mega.nz/linux/MEGAsync/xUbuntu_16.04/amd64/megasync-xUbuntu_16.04_amd64.deb" & spinner $!
    dpkg -i megasync-xUbuntu_16.04_amd64.deb >> xupdate.log 2>&1 & spinner $!
  else
    wget -q "https://mega.nz/linux/MEGAsync/xUbuntu_16.04/i386/megasync-xUbuntu_16.04_i386.deb" & spinner $!
    dpkg -i megasync-xUbuntu_16.04_amd64.deb >> xupdate.log 2>&1 & spinner $!
  fi
fi

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





