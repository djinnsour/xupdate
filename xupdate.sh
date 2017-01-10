#!/bin/bash

# Philip Wittamore - www.wittamore.com
#
# xupdate.sh version 0.6
#
# POST INSTALLATION SCRIPT FOR XUBUNTU 16.04 LTS
# The target is to create a "lazy users" Xubuntu installation
# CREDITS: Internet
#
# cd to the folder that contains this script (xupdate.sh)
# make the script executable with: chmod +x xupdate.sh
# then run sudo ./xupdate.sh

# clear terminal
printf "\033c"

# =============================================================
# text colour

GR='\033[1;32m'
RD='\033[1;31m'
NC='\033[0m'

echo -e "${GR}xupdate - a Xubuntu post installation script${NC}"

# =============================================================
# Make sure only root can run our script

if [ "$(id -u)" != "0" ]; then
   echo -e "${RD}This script must be run as root, exiting.${NC}"
   exit 1
fi

# =============================================================
# TEST INTERNET CONNECTION

echo -e "${GR}Testing internet connection...${NC}"
wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? -eq 0 ]]; then
        echo -e "${GR}Internet connection OK.${NC}"
else
        echo -e "${RD}This script requires an internet connection, exiting.${NC}"
        exit 1
fi

# =============================================================
# SELECT EXTRA PACKAGES

echo -e "${RD}Please indicate if you wish to install these extra applications:${NC}"
echo
echo -e "${GR}Skype - a proprietary messaging application.${NC}"
echo -e "${RD}WARNING: Skype is unsafe and not allowed in French universities.${NC}"
echo -e "${RD}If you just require Skype text messaging, select Franz instead.${NC}"
while true; do
    read -p "Do you wish to install Skype? : " yn
    case $yn in
        [Yy]* ) INSTSKYPE="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Ublock Origin - advert blocker for Firefox.${NC}"
while true; do
    read -p "Do you wish to install Ublock Origin? : " yn
    case $yn in
        [Yy]* ) INSTUBLOCK="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Numix - make your Linux desktop beautiful${NC}"
while true; do
    read -p "Do you wish to install the Numix theme? : " yn
    case $yn in
        [Yy]* ) INSTNUMIX="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Franz - a free messaging application${NC}"
while true; do
    read -p "Do you wish to install Franz? : " yn
    case $yn in
        [Yy]* ) INSTFRANZ="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Google Earth${NC}"
echo -e "${RD}requires sufficient video ressources{NC}"
while true; do
    read -p "Do you wish to install Google Earth? : " yn
    case $yn in
        [Yy]* ) INSTGEARTH="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Mega - 50Gb cloud storage with end to end encryption and GUI Linux client${NC}"
while true; do
    read -p "Do you wish to install Mega? : " yn
    case $yn in
        [Yy]* ) INSTMEGA="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Molotov - a free French TV application (only works in France)${NC}"
while true; do
    read -p "Do you wish to install Molotov? : " yn
    case $yn in
        [Yy]* ) INSTMOLOTOV="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done
echo
echo -e "${GR}Pipelight - enable the Windows Silverlight plugin in Firefox${NC}"
echo -e "${RD}NOTE: Firefox will terminate NPAPI support soon and Silverlight is dead${NC}"
while true; do
    read -p "Do you wish to install Pipelight? : " yn
    case $yn in
        [Yy]* ) INSTPIPELIGHT="1"; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y or n.";;
    esac
done

# =============================================================
# START

# clear terminal
printf "\033c"
echo -e "${GR}Starting Xubuntu post-installation script.${NC}"
echo -e "${GR}Please be patient and don't exit until you see FINISHED.${NC}"

#--------------------------------------------------------------
# FIND USER AND GROUP THAT RAN su or sudo su
XUSER=`logname`
XGROUP=`id -ng $XUSER`

#--------------------------------------------------------------
# GET ARCHITECTURE
MACHINE_TYPE=`uname -m`
if [ "$MACHINE_TYPE" == "x86_64" ]; then
  ARCH="64"
else
  ARCH="32"
fi

#--------------------------------------------------------------
# GET IP AND IS COUNTRY FRANCE
IP=`wget -qO- checkip.dyndns.org | sed -e 's/.*Current P Address: //' -e 's/<.*$//'`
FR=`wget -qO- ipinfo.io/$IP | grep -c '"country": "FR"'`
if [ "$FR" == "1" ]; then
  DESKTOP="Bureau"
else
  DESKTOP="Desktop"
fi

#--------------------------------------------------------------
# shut up installers
export DEBIAN_FRONTEND=noninteractive

#--------------------------------------------------------------
# ERROR LOGGING SETUP
echo 'XUPDATE LOG' > xupdate.log

#--------------------------------------------------------------
# use apt-get and not apt in shell scripts
xinstall () {
  echo "   installing $1 "
  apt-get install -q -y "$1" >> xupdate.log 2>&1 & spinner $!
}
xremove () {
  echo "   removing $1 "
  apt-get purge -q -y "$1" >> xupdate.log 2>&1 & spinner $!
}

#--------------------------------------------------------------
# XPI functions for installing firefox extensions

EXTENSIONS_SYSTEM='/usr/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/'
EXTENSIONS_USER=`echo /home/$XUSER/.mozilla/firefox/*.default/extensions/`

get_addon_id_from_xpi () { #path to .xpi file
    addon_id_line=`unzip -p $1 install.rdf | egrep '<em:id>' -m 1`
    addon_id=`echo $addon_id_line | sed "s/.*>\(.*\)<.*/\1/"`
    echo "$addon_id"
}

get_addon_name_from_xpi () { #path to .xpi file
    addon_name_line=`unzip -p $1 install.rdf | egrep '<em:name>' -m 1`
    addon_name=`echo $addon_name_line | sed "s/.*>\(.*\)<.*/\1/"`
    echo "$addon_name"
}

install_addon () {
    xpi="${PWD}/${1}"
    extensions_path=$2
    new_filename=`get_addon_id_from_xpi $xpi`.xpi
    new_filepath="${extensions_path}${new_filename}"
    addon_name=`get_addon_name_from_xpi $xpi`
    if [ -f "$new_filepath" ]; then
        echo "File already exists: $new_filepath"
        echo "Skipping installation for addon $addon_name."
    else
        cp "$xpi" "$new_filepath"
    fi
}

#--------------------------------------------------------------
# working spinner

spinner () { 
  local pid=$1 
  local delay=0.7
  while [ $(ps -eo pid | grep -c $pid) == "1" ]; do 
    for i in '\' '|' '/' '-'  ; do 
      printf ' [%c]\b\b\b\b' $i 
      sleep $delay 
    done 
  done 
  printf '\b\b\b\b'
}

# =============================================================
# ADD REPOSITORIES

echo -e "${GR}Adding repositories...${NC}"

# ubuntu partner (skype etc.)
add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner" -y >> xupdate.log 2>&1  & spinner $!

# Linrunner - supercedes laptop-tools and is indispensable on laptops
add-apt-repository ppa:linrunner/tlp -y >> xupdate.log 2>&1 & spinner $!

# Libreoffice - latest version
add-apt-repository ppa:libreoffice/ppa -y >> xupdate.log 2>&1 & spinner $!

# Google Chrome (not supported on 32bit)
if [ "$ARCH" == "64" ]; then
  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - & spinner $!
  echo "deb https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
fi

# =============================================================
# REMOVE
# we are replacing parole with VLC

echo -e "${GR}Removing files...${NC}"

xremove parole

# =============================================================
# UPDATE & UPGRADE

echo -e "${GR}Updating...${NC}"
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
echo -e "${GR}Upgrading...${NC}"
apt-get dist-upgrade -q -y >> xupdate.log 2>&1 & spinner $!

# =============================================================
# SYSTEM

echo -e "${GR}Setting up the system...${NC}"

#--------------------------------------------------------------
# PRELOAD 
# not for low memory systems, arbitrarily set to 2Gb
MEM=`free | grep "Mem:" | tr -s ' ' | cut -d ' ' -f2`
if (($MEM > 2097152)); then
  xinstall preload
fi

#--------------------------------------------------------------
# IF SSD
SSD=`cat /sys/block/sda/queue/rotational`
if [ "$SSD" == "0" ]; then
  # preload
  if [ -f "/etc/preload.conf" ]; then
    sed -i -e "s/sortstrategy = 3/sortstrategy = 0/g" /etc/preload.conf
  fi
  # fstab - keep tmp folder and logs in ram (desktop only)
  echo 'tmpfs /tmp     tmpfs defaults,noexec,nosuid,noatime,size=20% 0 0' >> /etc/fstab
  echo 'tmpfs /var/log tmpfs defaults,noexec,nosuid,noatime,mode=0755,size=20% 0 0' >> /etc/fstab
  echo ' ' >> /etc/fstab
  # fstrim is configured weekly by default
  # grub
  $FIND="GRUB_CMDLINE_LINUX_DEFAULT=\x22quiet splash\x22"
  $REPL="GRUB_CMDLINE_LINUX_DEFAULT=\x22elevator=deadline quiet splash\x22"
  sed -i "s/$FIND/$REPL/g" /etc/default/grub
  update-grub >> xupdate.log 2>&1
fi

#--------------------------------------------------------------
# cache for symbol tables. Qt / GTK programs will start a bit quicker and consume less memory
# http://vasilisc.com/speedup_ubuntu_eng#compose_cache
mkdir -p /home/$XUSER/.compose-cache

#--------------------------------------------------------------
# Get rid of “Sorry, Ubuntu xx has experienced internal error”
sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

#--------------------------------------------------------------
# Memory management
if [ "$SSD" == "0" ]; then
  echo "vm.swappiness=1" > /etc/sysctl.d/99-swappiness.conf
else
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
fi
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf >> xupdate.log 2>&1 

#--------------------------------------------------------------
# Enable unattended security upgrades
echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-updates.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-backports.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades

#--------------------------------------------------------------
# Set update periods
rm /etc/apt/apt.conf.d/10periodic
cat <<EOF > /etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
chmod 644 /etc/apt/apt.conf.d/10periodic

#--------------------------------------------------------------
# Manage Laptop battery & overheating 
LAPTOP=`laptop-detect; echo -e  $?`
if [ "$LAPTOP" == "0" ]; then
  xinstall tlp 
  xinstall tlp-rdw 
  # THINKPAD ONLY
  VENDOR=`cat /sys/devices/virtual/dmi/id/chassis_vendor`
  if [ "$VENDOR" == "LENOVO" ]; then
    xinstall tp-smapi-dkms 
    xinstall acpi-call-dkms 
  fi
  tlp start >> xupdate.log 2>&1
  systemctl enable tlp >> xupdate.log 2>&1
  systemctl enable tlp-sleep >> xupdate.log 2>&1
fi

#--------------------------------------------------------------
# Wifi power control off for faster wifi at a slight cost of battery
WIFI=`lspci | egrep -c -i 'wifi|wlan|wireless'`
if [ "$WIFI" == "1" ];
then
  WIFINAME=`iwgetid | cut -d ' ' -f 1`
  echo '#!/bin/sh' >  /etc/pm/power.d/wireless
  echo "/sbin/iwconfig $WIFINAME power off" >> /etc/pm/power.d/wireless
  chmod 755 /etc/pm/power.d/wireless
fi

#--------------------------------------------------------------
# Speed up gtk
echo "gtk-menu-popup-delay = 0" > /home/$XUSER/.gtkrc-2.0
echo "gtk-menu-popdown-delay = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-menu-bar-popup-delay = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-enable-animations = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-expand = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-initial = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-repeat = 0" >> /home/$XUSER/.gtkrc-2.0

#--------------------------------------------------------------
# FILE DEFAULTS
# override rhythmbox parole
# audio
sed -i -e "s/rhythmbox.desktop/vlc.desktop/g" /usr/share/applications/defaults.list
sed -i -e "s/parole.desktop/vlc.desktop/g" /usr/share/applications/defaults.list

#--------------------------------------------------------------
# MEDIA INSERT
# auto run inserted DVD's & CD's with VLC, and import photo's
xfconf-query -c thunar-volman -p /autoplay-audio-cds/command -n -t string -s "vlc cdda:///dev/sr0"
xfconf-query -c thunar-volman -p /autoplay-video-cds/command -n -t string -s "vlc dvd:///dev/sr0"
xfconf-query -c thunar-volman -p /autophoto/command -n -t string -s "shotwell"
# Set the default QT style
echo "QT_STYLE_OVERRIDE=gtk+" >> /etc/environment

# =============================================================
# INSTALL

echo -e "${GR}Package installation...${NC}"
echo -e "${GR}  Base...${NC}"

# Due to a bug in ttf-mscorefonts-installer, this package must be downloaded from Debian 
# and installed before the rest of the packages:
xinstall cabextract
wget -q http://ftp.de.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb >> xupdate.log 2>&1 & spinner $!
dpkg -i ttf-mscorefonts-installer_3.6_all.deb >> xupdate.log 2>&1 & spinner $!

xinstall xubuntu-restricted-extras
ubuntu-drivers autoinstall >> xupdate.log 2>&1 & spinner $!

# libdvdcss
echo -e "${GR}  Libdvdcss...${NC}"
xinstall libdvd-pkg
dpkg-reconfigure libdvd-pkg >> xupdate.log 2>&1 & spinner $!

echo -e "${GR}  Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

echo -e "${GR}  System tools...${NC}"

xinstall lsb-core
xinstall joe 
xinstall mc 
xinstall curl 
xinstall gparted
xinstall ppa-purge 
xinstall synaptic 
xinstall gdebi 
xinstall gksu 
xinstall psensor 
xinstall fancontrol 
xinstall indicator-cpufreq 
xinstall smartmontools 
xinstall gsmartcontrol 
xinstall mono-complete 
xinstall bleachbit 
xinstall gtk2-engines 
xinstall numlockx
xinstall deja-dup

# Devilspie allows setting application wm defaults
# for example: start Franz minimized (see below)
xinstall devilspie
mkdir -p /home/$XUSER/.devilspie
cat < <<EOF /home/$XUSER/.config/autostart/devilspie.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=devilspie
Comment=
Exec=/usr/bin/devilspie
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF

# Tool for enabling write support on NTFS disks
echo -e "${GR}  NTFS write support...${NC}"
xinstall ntfs-config 
if [ ! -d /etc/hal/fdi/policy ]; then
  mkdir -p /etc/hal/fdi/policy
fi

echo -e "${GR}  Compression tools...${NC}"

# compression
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

echo -e "${GR}  Printing...${NC}"

# Printing
xinstall cups-pdf 
xinstall hplip-gui 

# =============================================================
# ACCESSORIES

echo -e "${GR}  Accessories...${NC}"
 
xinstall gedit 
xinstall gedit-plugins 
xinstall gedit-developer-plugins  
xinstall deja-dup 
xinstall evince 
xinstall xpdf
xinstall rednotebook 
xinstall calibre 
xinstall scribus 
xinstall brasero 
xinstall typecatcher 
xinstall geany 
xinstall geany-plugin* 

# =============================================================
# DESKTOP

echo -e "${GR}  Desktop...${NC}"

xinstall plank
cat < <<EOF /home/$XUSER/.config/autostart/devilspie.desktop
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Plank
Comment=
Exec=/usr/bin/plank
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
EOF

# =============================================================
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
xinstall openshot 
xinstall dia-gnome 
xinstall inkscape 
xinstall blender 
xinstall blender-data 
xinstall glabels

# =============================================================
# AUDIO/VIDEO

echo -e "${GR}  Audio and Video...${NC}"

xinstall vlc 
xinstall handbrake
xinstall devede 
xinstall audacity 
xinstall lame 
xinstall libsox-fmt-all  
xinstall cheese 
xinstall mplayer 
xinstall gnome-mplayer 
xinstall kazam

# =============================================================
# OFFICE
# libreoffice - latest version from ppa

echo -e "${GR}  Libreoffice...${NC}"

xinstall libreoffice 
xinstall libreoffice-pdfimport
xinstall libreoffice-nlpsolver
xinstall libreoffice-gtk

if [ "$LANGUAGE" == "fr_FR" ]; then
  xinstall ibreoffice-l10n-fr 
  xinstall libreoffice-help-fr 
  xinstall hyphen-fr 
  # get the latest version by parsing telecharger.php
  wget -q http://www.dicollecte.org/grammalecte/telecharger.php  >> xupdate.log 2>&1 & spinner $!
  GOXT=`cat telecharger.php | grep "http://www.dicollecte.org/grammalecte/oxt/Grammalecte-fr" | cut -f4 -d '"'`
  if [ -f "*.oxt" ]; then
    wget -q $GOXT  >> xupdate.log 2>&1 & spinner $!
    unopkg add --shared -f G`echo $GOXT | cut -f2 -d 'G'`
  fi
fi

# =============================================================
# GAMES

echo -e "${GR}  Games...${NC}"

xinstall frozen-bubble 
xinstall pysolfc 
xinstall mahjongg 
xinstall aisleriot 
xinstall pingus 

# =============================================================
# EDUCATION

echo -e "${GR}  Education...${NC}"

xinstall stellarium

# =============================================================
# INTERNET

echo -e "${GR}  Internet...${NC}"

xinstall deluge-torrent
xinstall filezilla  

if [ "$ARCH" == "64" ]; then
  xinstall google-chrome-stable 
fi

# =============================================================
# WINE 
echo -e "${GR}  Wine...${NC}"
add-apt-repository ppa:wine/wine-builds -y >> xupdate.log 2>&1 & spinner $!
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
apt-get install -y -q --install-recommends wine-staging >> xupdate.log 2>&1 & spinner $!
xinstall winehq-staging
groupadd wine >> xupdate.log 2>&1
adduser $XUSER wine >> xupdate.log 2>&1

# =============================================================
# clean up

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1

# =============================================================
# SELECTED EXTRA APPLICATIONS

echo -e "${GR}Installing selected extra applications...${NC}"

#--------------------------------------------------------------
# Skype
if [ "$INSTSKYPE" == "1" ]; then
  xinstall skype
fi

#--------------------------------------------------------------
# Spotify
if [ "$INSTSPOTIFY" == "1" ]; then
echo -e "${GR}   installing Google Earth...${NC}"
gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv BBEBDCB318AD50EC6865090613B00F1FD2C19886 2>> xupdate.log
gpg --export --armor BBEBDCB318AD50EC6865090613B00F1FD2C19886 | apt-key add - >> xupdate.log 2>&1 
echo "deb http://repository.spotify.com stable non-free"  > /etc/apt/sources.list.d/spotify.list
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
xinstall spotify-client
fi

#--------------------------------------------------------------
# Google Earth
if [ "$INSTGEARTH" == "1" ]; then
echo -e "${GR}   installing Google Earth...${NC}"
if [ "$ARCH" == "64" ]; then
  wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb >> xupdate.log 2>&1 & spinner $!
  dpkg -i google-earth-stable_current_amd64.deb >> xupdate.log 2>&1 & spinner $!
else
  wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_i386.deb >> xupdate.log 2>&1 & spinner $!
  dpkg -i google-earth-stable_current_i386.deb >> xupdate.log 2>&1 & spinner $!
fi
fi

#--------------------------------------------------------------
# Numix
if [ "$INSTNUMIX" == "1" ]; then
echo -e "${GR}   installing Numix theme...${NC}"
# Numix
apt-add-repository ppa:numix/ppa -y >> xupdate.log 2>&1 & spinner $!
apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
xinstall numix-folders
xinstall numix-gtk-theme
xinstall numix-icon-theme
xinstall numix-icon-theme-circle 
xinstall numix-plank-theme
fi

#--------------------------------------------------------------
# Enable silverlight plugin in firefox
# Pipelight development has been discontinued, as Firefox is
# retiring NPAPI support soon, and Silverlight is dead
# see http://pipelight.net/
if [ "$INSTPIPELIGHT" == "1" ]; then  
  echo -e "${GR}   installing Pipelight...${NC}"
  add-apt-repository ppa:pipelight/stable -y >> xupdate.log 2>&1 & spinner $!
  apt-get -q -y update >> xupdate.log 2>&1 & spinner $!
  apt-get install -y -q --install-recommends pipelight-multi >> xupdate.log 2>&1 & spinner $!
  chmod 777 /usr/lib/pipelight/
  chmod 666 /usr/lib/pipelight/*
  pipelight-plugin --update -y  >> xupdate.log 2>&1
  sudo -u $XUSER pipelight-plugin -y --create-mozilla-plugins >> xupdate.log 2>&1
  sudo -u $XUSER pipelight-plugin -y --enable silverlight >> xupdate.log 2>&1
fi

#--------------------------------------------------------------
# Add Ublock Origin plugin to Firefox
if [ "$INSTUBLOCK" == "1" ]; then
echo -e "${GR}   installing Ublock Origin Firefox plugin...${NC}"
echo -e "${RD}   NOTE: Plugin must be activated manually in Firefox${NC}"
wget -q https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi >> xupdate.log 2>&1 & spinner $!
install_addon addon-607454-latest.xpi "$EXTENSIONS_SYSTEM" >> xupdate.log 2>&1
fi

#--------------------------------------------------------------
# FRANZ a free messaging app.
# Franz currently supports Slack, WhatsApp, WeChat, HipChat, Facebook Messenger, 
# Telegram, Google Hangouts, GroupMe, Skype and many more.
if [ "$INSTFRANZ" == "1" ]; then
echo -e "${GR}   installing Franz...${NC}"
# get latest version by parsing latest download page
wget -q https://github.com/meetfranz/franz-app/releases/latest 
mkdir -p /opt/franz
if [ "$ARCH" == "64" ]; then
  FRZ64=`cat latest | grep Franz-linux-x64 | grep meetfranz | cut -f2 -d '"'`
  wget -qO- https://github.com$FRZ64 | tar zxf - -C /opt/franz/  & spinner $!
fi
if [ "$ARCH" == "32" ]; then
  FRZ32=`cat latest | grep Franz-linux-ia32 | grep meetfranz | cut -f2 -d '"'`
  wget -qO- https://github.com/meetfranz$FRZ32 | tar zxf - -C /opt/franz/
fi
wget -q https://cdn-images-1.medium.com/max/360/1*v86tTomtFZIdqzMNpvwIZw.png -O /opt/franz/franz-icon.png 
if [ ! -f /usr/share/applications/franz.desktop ]; then
cat <<EOF > /usr/share/applications/Franz.desktop                                                                 
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=Franz
Comment=Franz is a free messaging app 
Exec=/opt/franz/Franz
Icon=/opt/franz/franz-icon.png
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
Categories=Network;Messaging;
EOF
fi
cp /usr/share/applications/franz.desktop /home/$XUSER/$DESKTOP 2>> xupdate.log
cp /usr/share/applications/franz.desktop /home/$XUSER/.config/autostart/ 2>> xupdate.log
cat <<EOF > /home/$XUSER/.devilspie/franz.ds
(if  
(is (application_name) "Franz")  
(begin (minimize) )  
)  
EOF
fi

#--------------------------------------------------------------
# MOLOTOV French TV online viewer (only works in France)
# It is impossible to obtain the latest version number
# so it has to be manually added here. Grrr...
if [ "$INSTMOLOTOV" == "1" ]; then
  echo -e "${GR}   installing Molotov...${NC}"
  # name of latest version
  MFILE='Molotov-1.1.2.AppImage'
  mkdir -p /opt/molotov
  xinstall libatk-adaptor 
  xinstall libgail-common 
  wget -qP /opt/molotov https://desktop-auto-upgrade.s3.amazonaws.com/linux/$MFILE & spinner $!
  if [ -f "/opt/molotov/$MFILE" ]; then
    chmod +x /opt/molotov/$MFILE
  fi
  # launch molotov to install desktop entry
  sudo -u $XUSER /opt/molotov/$MFILE &
fi

#--------------------------------------------------------------
# CLOUD STORAGE
# MEGA: 50Gb, end to end encryption, GUI Linux client
# HUBIC: 25Gb, command line only
# PCLOUD: 10Gb, encryption is premium feature, native Linux client
# DROPBOX: 2Gb, GUI client but xubuntu integration needs work
if [ "$INSTMEGA" == "1" ]; then
  echo -e "${GR}   installing Mega...${NC}"
  xinstall libc-ares2
  xinstall libcrypto++9v5
  if [ "$ARCH" == "64" ]; then
    wget -q https://mega.nz/linux/MEGAsync/xUbuntu_16.04/amd64/megasync-xUbuntu_16.04_amd64.deb & spinner $!
    dpkg -i megasync-xUbuntu_16.04_amd64.deb >> xupdate.log 2>&1 & spinner $!
  fi
  if [ "$ARCH" == "32" ]; then
    wget -q https://mega.nz/linux/MEGAsync/xUbuntu_16.04/i386/megasync-xUbuntu_16.04_i386.deb & spinner $!
    dpkg -i megasync-xUbuntu_16.04_amd64.deb >> xupdate.log 2>&1 & spinner $!
  fi
fi

# =============================================================
# LOCAL FILES

# Install extra fonts
# requires a folder named "fonts" containing extra ttf fonts

if [ -d "fonts" ]; then
  echo -e "${GR}Installing TTF fonts from folder 'fonts'...${NC}"
  mkdir /usr/share/fonts/truetype/xttf
  cp -r fonts/*.ttf /usr/share/fonts/truetype/xttf 2>> /dev/null  & spinner $!
  chmod -R 755 /usr/share/fonts/truetype/xttf
  fc-cache -fv > /dev/null
fi

# =============================================================
# FINISH

#--------------------------------------------------------------
# update system icon cache
echo -e "${GR}Update icon cache...${NC}"
for d in /usr/share/icons/*; do gtk-update-icon-cache -f -q $d >> xupdate.log 2>&1; done 

#--------------------------------------------------------------
# add default desktop launchers
echo -e "${GR}Install default desktop launchers...${NC}"
cp /usr/share/applications/firefox.desktop /home/$XUSER/$DESKTOP 2>> xupdate.log
cp /usr/share/applications/libreoffice-startcenter.desktop /home/$XUSER/$DESKTOP 2>> xupdate.log
chmod 775 /home/$XUSER/$DESKTOP/*.desktop

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y >> xupdate.log 2>&1  & spinner $!
apt-get autoremove >> xupdate.log 2>&1
apt-get clean >> xupdate.log 2>&1
update-grub >> xupdate.log 2>&1

# safely correct permissions because we are working as root
chown -R $XUSER:$XGROUP /home/$XUSER

echo -e "${GR}######## FINISHED ########${NC}"
echo
echo -e "${RD}Reboot now!${NC}"
echo





