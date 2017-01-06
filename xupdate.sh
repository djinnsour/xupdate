#!/bin/bash

# version 0.3
# 6 January 2017 - Philip Wittamore

# POST INSTALLATION SCRIPT FOR XUBUNTU 16.04
# The target is to create a "lazy users" Xubuntu installation
# CREDITS: Internet

# cd to the folder that contains this script (xupdate.sh)
# make the script executable with: chmod 777 xupdate.sh
# then run sudo ./xupdate.sh

# CHANGELOG since 0.2
# added xpi functions and firefox ublock origin plugin installation
# corrected xconf-query autorun command (added create if doesn't exist)
# bug fixes

# =============================================================
# Make sure only root can run our script

if [ "$(id -u)" != "0" ]; then
   echo -e "This script must be run as root" 1>&2
   exit 1
fi

# =============================================================
# TEST INTERNET CONNECTION

wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? -eq 0 ]]; then
        echo -e "Internet connection OK."
else
        echo -e "No internet connection, exiting."
        exit 1
fi

# =============================================================
# START

# FIND USER AND GROUP THAT RAN su or sudo su
XUSER=`logname`
XGROUP=`id -ng $XUSER`

# shut up installers
export DEBIAN_FRONTEND=noninteractive

GR='\033[1;32m'
RD='\033[1;31m'
NC='\033[0m'
echo -e "${GR}Starting Xubuntu post-installation script.${NC}"
echo -e "${GR}Please be patient and don't exit until you see FINISHED.${NC}"

# ERROR LOGGING SETUP
echo 'Errors' > xupdate_error.log

# use apt-get and not apt in shell scripts
xinstall () {
  apt-get install -q -y $1 > /dev/null 2>> xupdate_error.log
}
xremove () {
  apt-get purge -q -y $1 > /dev/null 2>> xupdate_error.log
}

# xpi functions for installing firefox extensions

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

# =============================================================
# ADD REPOSITORIES

echo -e "${GR}Adding repositories...${NC}"

# Linrunner
add-apt-repository ppa:linrunner/tlp -y > /dev/null 2>> xupdate_error.log

# Wine & silverlight
add-apt-repository ppa:pipelight/stable -y > /dev/null 2>> xupdate_error.log

# Libreoffice
add-apt-repository ppa:libreoffice/ppa -y > /dev/null 2>> xupdate_error.log

# Google Chrome (not supported on 32bit)
if [ "$ARCH" == "64" ]; then
  wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
  echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
fi

# =============================================================
# REMOVE
# we are replacing parole with VLC

echo -e "${GR}Removing files...${NC}"

xremove parole

# =============================================================
# UPDATE & UPGRADE

echo -e "${GR}Update & upgrade...${NC}"
apt-get -q -y update > /dev/null 2>> xupdate_error.log
apt-get dist-upgrade -q -y > /dev/null 2>> xupdate_error.log

# =============================================================
# SYSTEM

echo -e "${GR}Setting up system...${NC}"

# GET IP AND IS COUNTRY FRANCE
IP=`wget -qO- checkip.dyndns.org | sed -e 's/.*Current P Address: //' -e 's/<.*$//'`
FR=`wget -qO- ipinfo.io/$IP | grep -c '"country": "FR"'`

# GET ARCHITECTURE
MACHINE_TYPE=`uname -m`
if [ "$MACHINE_TYPE" == "x86_64" ]; then
  ARCH="64"
else
  ARCH="32"
fi

# PRELOAD 
# not for low memory systems, arbitrarily set to 2Gb
MEM=`free | grep "Mem:" | tr -s ' ' | cut -d ' ' -f2`
if (($MEM > 2097152)); then
  xinstall preload
fi

LAPTOP=`laptop-detect; echo -e  $?`

# IF SSD
SSD=`cat /sys/block/sda/queue/rotational`
if [ "$SSD" == "0" ]; then
  # preload
  if [ -f "/etc/preload.conf" ]; then
    sed -i -e "s/sortstrategy = 3/sortstrategy = 0/g" /etc/preload.conf
  fi
  # fstab - keep tmp folder and logs in ram (desktop only)
  echo 'tmpfs /tmp     tmpfs defaults,noatime,size=1g 0 0' >> /etc/fstab
  echo 'tmpfs /var/log tmpfs defaults,nosuid,nodev,noatime,mode=0755,size=5% 0 0' >> /etc/fstab
  echo ' ' >> /etc/fstab
  # fstrim is configured weekly by default
fi

# cache for symbol tables. Qt / GTK programs will start a bit quicker and consume less memory
# http://vasilisc.com/speedup_ubuntu_eng#compose_cache
mkdir /home/$XUSER/.compose-cache

# Get rid of “Sorry, Ubuntu xx has experienced internal error”
sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# Memory management
if [ "$SSD" == "0" ]; then
  echo "vm.swappiness=1" > /etc/sysctl.d/99-swappiness.conf
else
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
fi
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

# Enable unattended security upgrades
echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-updates.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i '/^\/\/.*-backports.*/s/^\/\//  /g' /etc/apt/apt.conf.d/50unattended-upgrades

# Manage Laptop battery & overheating 
if [ "$LAPTOP" == "0" ]; then
  xinstall tlp 
  xinstall tlp-rdw 
  # THINKPAD ONLY
  VENDOR=`cat /sys/devices/virtual/dmi/id/chassis_vendor`
  if [ "$VENDOR" == "LENOVO" ]; then
    xinstall tp-smapi-dkms 
    xinstall acpi-call-tools 
  fi
  tlp start
  systemctl enable tlp
  systemctl enable tlp-sleep
fi

# Wifi power control off for faster wifi at a slight cost of battery
WIFI=`lspci | egrep -c -i 'wifi|wlan|wireless'`
if [ "$WIFI" == "1" ];
then
  WIFINAME=`iwgetid | cut -d ' ' -f 1`
  echo '#!/bin/sh' >  /etc/pm/power.d/wireless
  echo "/sbin/iwconfig $WIFINAME power off" >> /etc/pm/power.d/wireless
  chmod 755 /etc/pm/power.d/wireless
fi

# Speed up gtk
echo "gtk-menu-popup-delay = 0" > /home/$XUSER/.gtkrc-2.0
echo "gtk-menu-popdown-delay = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-menu-bar-popup-delay = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-enable-animations = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-expand = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-initial = 0" >> /home/$XUSER/.gtkrc-2.0
echo "gtk-timeout-repeat = 0" >> /home/$XUSER/.gtkrc-2.0

# FILE DEFAULTS
# overrides rhythmbox parole
# audio
sed -i -e "s/rhythmbox.desktop/vlc.desktop/g" /usr/share/applications/defaults.list
sed -i -e "s/parole.desktop/vlc.desktop/g" /usr/share/applications/defaults.list

# MEDIA INSERT
# auto run inserted DVD's and CD's with VLC instead of the defaults
xfconf-query -c thunar-volman -p /autoplay-audio-cds/command -n -t string -s "vlc cdda:///dev/sr0"
xfconf-query -c thunar-volman -p /autoplay-video-cds/command -n -t string -s "vlc dvd:///dev/sr0"
# Set the default QT style
echo "QT_STYLE_OVERRIDE=gtk+" >> /etc/environment

# =============================================================
# INSTALL

echo -e "${GR}Package installation...${NC}"
echo -e "${GR}  Base...${NC}"
# Due to a bug in ttf-mscorefonts-installer, this package must be downloaded from Debian 
# and installed before the rest of the packages:
xinstall cabextract
wget -q http://ftp.de.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb
dpkg -i ttf-mscorefonts-installer_3.6_all.deb

xinstall xubuntu-restricted-extras
ubuntu-drivers autoinstall

# libdvdcss
echo -e "${GR}  Libdvdcss...${NC}"
xinstall libdvd-pkg
dpkg-reconfigure libdvd-pkg > /dev/null 2>> xupdate_error.log

echo -e "${GR}  Cleaning up...${NC}"

apt-get install -f -y > /dev/null 2>> xupdate_error.log

echo -e "${GR}  System...${NC}"

xinstall lsb-core
xinstall joe 
xinstall mc 
xinstall curl 
xinstall gparted 
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

echo -e "${GR}  Compression tools...${NC}"

# compression
xinstall unace 
xinstall rar 
xinstall unrar 
xinstall p7zip-rar 
xinstall p7zip  
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

xinstall plank 
xinstall gedit 
xinstall gedit-plugins 
xinstall gedit-developer-plugins 
xinstall filezilla 
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
xinstall openshot 
xinstall dia-gnome 
xinstall inkscape 
xinstall blender 
xinstall blender-data 
xinstall sweethome3d 
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

# =============================================================
# OFFICE
# libreoffice - latest version from ppa

echo -e "${GR}  Libreoffice...${NC}"

xinstall libreoffice 
xinstall libreoffice-pdfimport
xinstall libreoffice-nlpsolver

if [ "$LANGUAGE" == "fr_FR" ]; then
  wget -q http://www.dicollecte.org/grammalecte/oxt/Grammalecte-fr-v0.5.14.oxt
  unopkg add --shared Grammalecte-fr-v0.5.14.oxt
fi
if [ "$LANGUAGE" == "en_GB" ]; then
  wget -q http://extensions.libreoffice.org/extension-center/american-british-canadian-spelling-hyphen-thesaurus-dictionaries/releases/3.0/kpp-british-english-dictionary-674039-word-list.oxt
  unopkg add --shared kpp-british-english-dictionary-674039-word-list.oxt
  xinstall myspell-en-gb 
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
# INTERNET

echo -e "${GR}  Internet...${NC}"

xinstall deluge-torrent  

if [ "$ARCH" == "64" ]; then
  xinstall google-chrome-stable 
fi

# =============================================================
# clean up

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y > /dev/null 2>> xupdate_error.log

# =============================================================
# LOCAL FILES

# Install extra fonts
# requires a folder named "fonts" containing extra ttf fonts

if [ -d "fonts" ]; then
  echo -e "${GR}Installing TTF fonts from folder 'fonts'...${NC}"
  mkdir /usr/share/fonts/truetype/xttf
  cp -r fonts/*.ttf /usr/share/fonts/truetype/xttf
  chmod -R 755 /usr/share/fonts/truetype/xttf
  fc-cache -fv > /dev/null
fi

# =============================================================
# OTHER

echo -e "${GR}Installing some more stuff...${NC}"

# Tool for enabling write support on NTFS disks
echo -e "${GR}  NTFS write support...${NC}"
xinstall ntfs-config 
mkdir -p /etc/hal/fdi/policy

# Wine 
echo -e "${GR}  Wine...${NC}"
xinstall wine-staging 
xinstall wine-staging-compat 
adduser $XUSER wine

# Enable silverlight plugin in firefox
echo -e "${GR}  Pipelight...${NC}"
xinstall pipelight-multi 
chmod 777 /usr/lib/pipelight/
chmod 666 /usr/lib/pipelight/*
su $XUSER pipelight-plugin --update -y
su $XUSER pipelight-plugin --enable silverlight -y
su $XUSER pipelight-plugin --create-mozilla-plugins -y

# Add Ublock Origin plugin to Firefox
wget https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi
install_addon addon-607454-latest.xpi "$EXTENSIONS_SYSTEM"

# Franz
echo -e "${GR}  Franz...${NC}"
mkdir -p /opt/franz
if [ "$ARCH" == "64" ]; then
  wget -qO- https://github.com/meetfranz/franz-app/releases/download/4.0.4/Franz-linux-x64-4.0.4.tgz | tar zxf - -C /opt/franz/
fi
if [ "$ARCH" == "32" ]; then
  wget -qO- https://github.com/meetfranz/franz-app/releases/download/4.0.4/Franz-linux-ia32-4.0.4.tgz | tar zxf - -C /opt/franz/
fi
wget -q https://cdn-images-1.medium.com/max/360/1*v86tTomtFZIdqzMNpvwIZw.png -O /opt/franz/franz-icon.png 
cat <<EOF > /usr/share/applications/franz.desktop                                                                 
[Desktop Entry]
Name=Franz
Comment=
Exec=/opt/franz/Franz
Icon=/opt/franz/franz-icon.png
Terminal=false
Type=Application
Categories=Messaging,Internet
EOF

# French TV online viewer (only works in France)
if [ "$FR" == "1" ]; then
  echo -e "${GR}  Molotov...${NC}"
  mkdir -p /opt/molotov
  xinstall libatk-adaptor 
  xinstall libgail-common 
  wget -P /opt/molotov https://desktop-auto-upgrade.s3.amazonaws.com/linux/Molotov-1.1.2.AppImage
  chmod +x /opt/molotov/*
  # launch it to install desktop entry
  su $XUSER /opt/molotov/Molotov-1.1.2.AppImage &
fi

# update system icon cache
echo -e "${GR}  Update icon cache...${NC}"
for d in /usr/share/icons/*; do gtk-update-icon-cache -f -q $d 2>> /dev/null; done

# =============================================================
# FINISH

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y > /dev/null
apt-get autoremove > /dev/null
apt-get clean > /dev/null
update-grub > /dev/null

# safely correct permissions because we are working as root
chown -R $XUSER:$XGROUP /home/$XUSER

ERRORS=`wc -l < xupdate_error.log`
if [ ! "$ERRORS" == "1" ]; then
  echo -e "${RD}$ERRORS lines in xupdate_error.log${NC}"
fi

echo -e "${GR}######## FINISHED ########${NC}"




