# xupdate

A post installation script for fresh installs of Xubuntu 16.04 LTS

A lazy installation for repair shops or noobs

CREDITS: Internet

English or French

HOWTO:

1. download xupdate.sh

2. open a terminal

3. cd to the folder that contains the script (xupdate.sh)

4. chmod +x xupdate.sh

5. sudo ./xupdate.sh

# CHANGELOG

- syntax corrected with shellcheck
- added conky
- added cowsay (thanks to wertperch)
- bug fixes

**version 0.8**

- added Krita in optional packages
- added Fuse for appimages
- changed method of defining users DESKTOP (thanks to Seebz)
- added drop down terminal upon F12 (thanks to Seebz)
- Plank is now optional with settings in menu
- added Terminal defaults
- fixed i386 package dependancies for 64 bit google earth
- bugfixes

**version 0.7**

- added optional package selection using dialog
- removed ristretto, set shotwell viewer as default (allows printing)
- added ctrl+alt+backspace
- added gnome-search-tool, searchmonkey
- Wine is now an optional package

**version 0.6**

- optional package are now proposed for installation at the start of the script
 - Skype, Ublock Origin, Numix theme, Franz, Google Earth, Mega, Molotov, Wine, Pipelight
- only one log now, xupdate.log
- added Devilspie
- optional package: added Skype
- optional package: added MEGA cloud storage, because
  - MEGA: 50Gb, end to end encryption, GUI Linux client
  - HUBIC: 25Gb, command line only
  - PCLOUD: 10Gb, encryption is premium feature, GUI Linux client
  - DROPBOX: 2Gb, GUI client but xubuntu integration needs work
- optional package: added spotify client

**version 0.5**

- added spinner to indicate progress
- added appearance packages (numix icons and gtk theme)
- added education packages (stellarium and google earth)
- fixed silverlight installation (but hey, it's dead)
- added max scrollback and better font size for XFCE4 Terminal
- set apt update periods
- various bug fixes

**version 0.4**

- better latest version detection for Franz and Grammalecte
- Fixed chrome installation - machine detection moved higher

**version 0.3**

- added xpi functions and firefox ublock origin plugin installation
- corrected xconf-query autorun command (added create if doesn't exist)
- better grammalecte installation - detect latest version by parsing download page
- various bug fixes

**version 0.2 = stabilized version**

**version 0.1 = nearly there**
