#!/bin/sh
#
# Kindle Touch JailBreak Uninstaller
# Heavily based on stuff created by Yifan Lu <http://yifan.lu/>
#
# $Id: uninstall.sh 10836 2014-08-22 15:40:00Z NiLuJe $
#
##

HACKNAME="jailbreak"

# Pull libOTAUtils for logging & progress handling
[ -f ./libotautils5 ] && source ./libotautils5


## Here we go :)
KEY_DIR=/etc/uks
otautils_update_progressbar

# Uninstall the JailBreak key
logmsg "I" "uninstall" "" "Removing the jailbreak key"
[ -f "${KEY_DIR}/pubdevkey01.pem" ] && rm -f "${KEY_DIR}/pubdevkey01.pem"
otautils_update_progressbar

# Don't uninstall the Kindlet keys because they could have been modified legitimately

# Done
logmsg "I" "uninstall" "" "done"
otautils_update_progressbar

return 0
