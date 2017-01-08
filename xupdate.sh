#!/bin/bash

# Philip Wittamore - www.wittamore.com
#
# xupdate.sh version 0.5
#
# POST INSTALLATION SCRIPT FOR XUBUNTU 16.04 LTS
# The target is to create a "lazy users" Xubuntu installation
# CREDITS: Internet
#
# cd to the folder that contains this script (xupdate.sh)
# make the script executable with: chmod +x xupdate.sh
# then run sudo ./xupdate.sh

# =============================================================
# text colour

GR='\033[1;32m'
RD='\033[1;31m'
NC='\033[0m'

# =============================================================
# Make sure only root can run our script

if [ "$(id -u)" != "0" ]; then
   echo -e "${RD}This script must be run as root, exiting.${NC}" 1>&2
   exit 1
fi

# =============================================================
# TEST INTERNET CONNECTION

wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? -eq 0 ]]; then
        echo -e "${GR}Internet connection OK.${NC}"
else
        echo -e "${RD}No internet connection, exiting.${NC}"
        exit 1
fi

# =============================================================
# START

# FIND USER AND GROUP THAT RAN su or sudo su
XUSER=`logname`
XGROUP=`id -ng $XUSER`

# GET ARCHITECTURE
MACHINE_TYPE=`uname -m`
if [ "$MACHINE_TYPE" == "x86_64" ]; then
  ARCH="64"
else
  ARCH="32"
fi

# shut up installers
export DEBIAN_FRONTEND=noninteractive

echo -e "${GR}Starting Xubuntu post-installation script.${NC}"
echo -e "${GR}Please be patient and don't exit until you see FINISHED.${NC}"

# ERROR LOGGING SETUP
echo 'Errors' > xupdate_error.log

# use apt-get and not apt in shell scripts
xinstall () {
  echo "   installing $1 "
  apt-get install -q -y $1 > /dev/null 2>> xupdate_error.log & spinner $!
}
xremove () {
  echo "   removing $1 "
  apt-get purge -q -y $1 > /dev/null 2>> xupdate_error.log & spinner $!
}

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

# working spinner

spinner () { 
  local pid=$1 
  local delay=0.25 
  while [ $(ps -eo pid | grep $pid) ]; do 
    for i in \| / - \\; do 
      printf ' [%c]\b\b\b\b' $i 
      sleep $delay 
    done 
  done 
  printf '\b\b\b\b'
}

# =============================================================
# ADD REPOSITORIES

echo -e "${GR}Adding repositories...${NC}"

# ubuntu partner
sudo add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner"

# Linrunner
add-apt-repository ppa:linrunner/tlp -y > /dev/null 2>> xupdate_error.log & spinner $!

# Wine & silverlight
add-apt-repository ppa:pipelight/stable -y > /dev/null 2>> xupdate_error.log & spinner $!

# Libreoffice
add-apt-repository ppa:libreoffice/ppa -y > /dev/null 2>> xupdate_error.log & spinner $!

# Numix
apt-add-repository ppa:numix/ppa -y > /dev/null 2>> xupdate_error.log & spinner $!

# Spotify
# can't silence apt-key
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886 
echo deb http://repository.spotify.com stable non-free  > /etc/apt/sources.list.d/spotify.list

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
apt-get -q -y update > /dev/null 2>> xupdate_error.log & spinner $!
echo -e "${GR}Upgrading...${NC}"
apt-get dist-upgrade -q -y > /dev/null 2>> xupdate_error.log & spinner $!

# =============================================================
# SYSTEM

echo -e "${GR}Setting up system...${NC}"

#--------------------------------------------------------------
# GET IP AND IS COUNTRY FRANCE
IP=`wget -qO- checkip.dyndns.org | sed -e 's/.*Current P Address: //' -e 's/<.*$//'`
FR=`wget -qO- ipinfo.io/$IP | grep -c '"country": "FR"'`

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
  echo 'tmpfs /tmp     tmpfs defaults,noatime,size=1g 0 0' >> /etc/fstab
  echo 'tmpfs /var/log tmpfs defaults,nosuid,nodev,noatime,mode=0755,size=5% 0 0' >> /etc/fstab
  echo ' ' >> /etc/fstab
  # fstrim is configured weekly by default
  # grub
  $FIND="GRUB_CMDLINE_LINUX_DEFAULT=\x22quiet splash\x22"
  $REPL="GRUB_CMDLINE_LINUX_DEFAULT=\x22elevator=deadline quiet splash\x22"
  sed -i "s/$FIND/$REPL/g" /etc/default/grub
  update-grub > /dev/null 2>> xupdate_error.log
fi

#--------------------------------------------------------------
# cache for symbol tables. Qt / GTK programs will start a bit quicker and consume less memory
# http://vasilisc.com/speedup_ubuntu_eng#compose_cache
if [ ! -d /home/$XUSER/.compose-cache ]; then
  mkdir /home/$XUSER/.compose-cache
fi

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
sysctl -p /etc/sysctl.d/99-swappiness.conf > /dev/null 

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
  tlp start
  systemctl enable tlp
  systemctl enable tlp-sleep
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
# overrides rhythmbox parole
# audio
sed -i -e "s/rhythmbox.desktop/vlc.desktop/g" /usr/share/applications/defaults.list
sed -i -e "s/parole.desktop/vlc.desktop/g" /usr/share/applications/defaults.list

#--------------------------------------------------------------
# MEDIA INSERT
# auto run inserted DVD's and CD's with VLC instead of the defaults
xfconf-query -c thunar-volman -p /autoplay-audio-cds/command -n -t string -s "vlc cdda:///dev/sr0"
xfconf-query -c thunar-volman -p /autoplay-video-cds/command -n -t string -s "vlc dvd:///dev/sr0"
# Set the default QT style
echo "QT_STYLE_OVERRIDE=gtk+" >> /etc/environment

#--------------------------------------------------------------
# TERMINAL
# max scrollback in XFCE4 terminal
if [ ! -d /home/$XUSER/.config/xfce4/terminal ]; then
	mkdir -p /home/$XUSER/.config/xfce4/terminal
]
if [ ! -f /home/$XUSER/.config/xfce4/terminal/terminalrc ]; then
	touch /home/$XUSER/.config/xfce4/terminal/terminalrc
fi
NUM=`grep -c "ScrollingLines" /home/$XUSER/.config/xfce4/terminal/terminalrc`
if [ "$NUM" == "0" ]; then
  echo "ScrollingLines=1048576" >> /home/$XUSER/.config/xfce4/terminal/terminalrc 
fi
sed -i '/^FontName*/d' /home/$XUSER/.config/xfce4/terminal/terminalrc
echo 'FontName=DejaVu Sans Mono 11' >> /home/$XUSER/.config/xfce4/terminal/terminalrc


# =============================================================
# INSTALL

echo -e "${GR}Package installation...${NC}"
echo -e "${GR}  Base...${NC}"

# Due to a bug in ttf-mscorefonts-installer, this package must be downloaded from Debian 
# and installed before the rest of the packages:
xinstall cabextract
wget -q http://ftp.de.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb > /dev/null & spinner $!
dpkg -i ttf-mscorefonts-installer_3.6_all.deb > /dev/null 2>> xupdate_error.log & spinner $!

xinstall xubuntu-restricted-extras
ubuntu-drivers autoinstall > /dev/null & spinner $!

# libdvdcss
echo -e "${GR}  Libdvdcss...${NC}"
xinstall libdvd-pkg
dpkg-reconfigure libdvd-pkg > /dev/null 2>> xupdate_error.log & spinner $!

echo -e "${GR}  Cleaning up...${NC}"

apt-get install -f -y > /dev/null 2>> xupdate_error.log

echo -e "${GR}  System...${NC}"

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
xinstall neofetch

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

xinstall plank 
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
xinstall spotify-client
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
  wget -q http://www.dicollecte.org/grammalecte/telecharger.php  & spinner $!
  GOXT=`cat telecharger.php | grep "http://www.dicollecte.org/grammalecte/oxt/Grammalecte-fr" | cut -f4 -d '"'`
  if [ -f "*.oxt" ]; then
    wget -q $GOXT
    unopkg add --shared -f Grammalecte-fr-*.oxt
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

echo "   installing Google Earth"
if [ "$ARCH" == "64" ]; then
  wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb 2>> xupdate_error.log & spinner $!
  dpkg -i google-earth-stable_current_amd64.deb > /dev/null 2>> xupdate_error.log & spinner $!
else
  wget -q http://dl.google.com/dl/earth/client/current/google-earth-stable_current_i386.deb 2>> xupdate_error.log & spinner $!
  dpkg -i google-earth-stable_current_i386.deb > /dev/null 2>> xupdate_error.log & spinner $!
fi

# =============================================================
# INTERNET

echo -e "${GR}  Internet...${NC}"

xinstall deluge-torrent
xinstall filezilla  

if [ "$ARCH" == "64" ]; then
  xinstall google-chrome-stable 
fi

# =============================================================
# APPEARANCE

echo -e "${GR}  Appearance...${NC}"

xinstall numix-folders
xinstall numix-gtk-theme
xinstall numix-icon-theme
xinstall numix-icon-theme-circle 
xinstall numix-plank-theme

# =============================================================
# clean up

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y > /dev/null 2>> xupdate_error.log

# =============================================================
# OTHER

echo -e "${GR}Installing some more stuff...${NC}"

# Tool for enabling write support on NTFS disks
echo -e "${GR}  NTFS write support...${NC}"
xinstall ntfs-config 
if [ ! -d /etc/hal/fdi/policy ]; then
  mkdir -p /etc/hal/fdi/policy
fi

#--------------------------------------------------------------
# Wine 
echo -e "${GR}  Wine...${NC}"
xinstall wine-staging 
xinstall wine-staging-compat
groupadd wine 2>> xupdate_error.log
adduser $XUSER wine 2>> xupdate_error.log

#--------------------------------------------------------------
# Enable silverlight plugin in firefox
# Pipelight development has been discontinued, as Firefox is
# retiring NPAPI support soon, and Silverlight is dead
# see http://pipelight.net/
echo -e "${GR}  Silverlight plugin for Firefox...${NC}"
echo -e "${RD}  NOTE: Firefox will terminate NPAPI support soon and Silverlight is dead${NC}"
apt-get install -y -q --install-recommends pipelight-multi > /dev/null 2>> xupdate_error.log & spinner $!
chmod 777 /usr/lib/pipelight/
chmod 666 /usr/lib/pipelight/*
pipelight-plugin --update -y  2>> xupdate_error.log
sudo -u $XUSER pipelight-plugin -y --create-mozilla-plugins 2>> xupdate_error.log
sudo -u $XUSER pipelight-plugin -y --enable silverlight 2>> xupdate_error.log

#--------------------------------------------------------------
# Add Ublock Origin plugin to Firefox
echo -e "${GR}  Ublock Origin Firefox plugin...${NC}"
echo -e "${RD}  NOTE: Must be activated manually in Firefox${NC}"
wget -q https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi
install_addon addon-607454-latest.xpi "$EXTENSIONS_SYSTEM" 2>> xupdate_error.log

#--------------------------------------------------------------
# FRANZ a free messaging app.
# Franz currently supports Slack, WhatsApp, WeChat, HipChat, Facebook Messenger, 
# Telegram, Google Hangouts, GroupMe, Skype and many more.
echo -e "${GR}  Franz...${NC}"
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
fi

#--------------------------------------------------------------
# MOLOTOV French TV online viewer (only works in France)
# It is impossible to obtain the latest version number
# so it has to be manually added here. Grrr...
if [ "$FR" == "1" ]; then
  echo -e "${GR}  Molotov...${NC}"
  echo -e "${RD}  running molotov to install desktop entry${NC}"
  # name of latest version
  MFILE='Molotov-1.1.2.AppImage'
  mkdir -p /opt/molotov
  xinstall libatk-adaptor 
  xinstall libgail-common 
  wget -qP /opt/molotov https://desktop-auto-upgrade.s3.amazonaws.com/linux/$MFILE & spinner $!
  if [ -f "/opt/molotov/$MFILE" ]; then
    chmod +x /opt/molotov/$MFILE
    # launch to install desktop entry
    sudo -u $XUSER /opt/molotov/$MFILE > /dev/null &
  fi
fi

--------------------------------------------------------------
# CLOUD STORAGE
# MEGA: 50Gb, end to end encryption, GUI Linux client
# HUBIC: 25Gb, command line only
# PCLOUD: 10Gb, encryption is premium feature, native Linux client
# DROPBOX: 2Gb, GUI client but xubuntu integration needs work

if [ "$ARCH" == "64" ]; then
  wget -q https://mega.nz/linux/MEGAsync/xUbuntu_16.04/amd64/megasync-xUbuntu_16.04_amd64.deb & spinner $!
  dpkg -i megasync-xUbuntu_16.04_amd64.deb > /dev/null 2>> xupdate_error.log & spinner $!
fi
if [ "$ARCH" == "32" ]; then
  wget -q https://mega.nz/linux/MEGAsync/xUbuntu_16.04/i386/megasync-xUbuntu_16.04_i386.deb & spinner $!
  dpkg -i megasync-xUbuntu_16.04_amd64.deb > /dev/null 2>> xupdate_error.log & spinner $!
fi

#--------------------------------------------------------------
# update system icon cache
echo -e "${GR}  Update icon cache...${NC}"
for d in /usr/share/icons/*; do gtk-update-icon-cache -f -q $d > /dev/null 2>> /dev/null; done 

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

echo -e "${GR}Cleaning up...${NC}"

apt-get install -f -y > /dev/null 2>> xupdate_error.log  & spinner $!
apt-get autoremove > /dev/null 2>> xupdate_error.log
apt-get clean > /dev/null 2>> xupdate_error.log
update-grub > /dev/null 2>> xupdate_error.log

# safely correct permissions because we are working as root
chown -R $XUSER:$XGROUP /home/$XUSER

ERRORS=`wc -l < xupdate_error.log`
if [ ! "$ERRORS" == "1" ]; then
  echo -e "${RD}$ERRORS lines in xupdate_error.log${NC}"
fi

echo -e "${GR}######## FINISHED ########${NC}"





