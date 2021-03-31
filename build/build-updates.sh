#!/bin/bash -e
#
# $Id: build-updates.sh 17386 2020-05-24 01:46:32Z NiLuJe $
#

HACKNAME="jailbreak"
HACKDIR="JailBreak"
PKGNAME="${HACKNAME}"
PKGVER="1.16.N"

# Setup KindleTool packaging metadata flags to avoid cluttering the invocations
PKGREV="$(svnversion -c .. | awk '{print $NF}' FS=':' | tr -d 'P')"
KT_PM_FLAGS=( "-xPackageName=${HACKDIR}" "-xPackageVersion=${PKGVER}-r${PKGREV}" "-xPackageAuthor=ixtab, NiLuJe, yifanlu, yossarian17" "-xPackageMaintainer=NiLuJe" "-X" )

# We need kindletool (https://github.com/NiLuJe/KindleTool) in $PATH
if (( $(kindletool version | wc -l) == 1 )) ; then
	HAS_KINDLETOOL="true"
fi

if [[ "${HAS_KINDLETOOL}" != "true" ]] ; then
	echo "You need KindleTool (https://github.com/NiLuJe/KindleTool) to build this package."
	exit 1
fi

# We also need GNU tar
if [[ "$(uname -s)" == "Darwin" ]] ; then
	TAR_BIN="gtar"
else
	TAR_BIN="tar"
fi
if ! ${TAR_BIN} --version | grep -q "GNU tar" ; then
	echo "You need GNU tar to build this package."
	exit 1
fi

# Pickup our common stuff... We leave it in our staging wd so it ends up in the source package.
if [[ ! -d "../../Common" ]] ; then
        echo "The tree isn't checked out in full, missing the Common directory..."
        exit 1
fi
# LibOTAUtils 5
ln -f ../../Common/lib/libotautils5 ./libotautils5
# FBInk
ln -f ../../Common/bin/fbink ./fbink
# Pickup our DevCerts stuff... We leave it in our staging wd so it ends up in the source package.
if [[ ! -d "../../DevCerts" ]] ; then
        echo "The tree isn't checked out in full, missing the DevCerts directory..."
        exit 1
fi
for mkk_file in json_simple-1.1.jar developer.keystore gandalf bridge.conf ; do
	ln -f ../../DevCerts/src/install/${mkk_file} ./${mkk_file}
done

### FW 5.0.x
# By yifanlu & ixtab (http://yifan.lu/p/kindle-touch-jailbreak/)
###

## Install
# Prepare the directory layout for our data.tar.gz...
mkdir -p ../src/system ../src/wan

# Copy our payload
ln -f ../src/install.sh ../src/system/mntus.params
ln -f ../src/install.sh ../src/wan/info

# Craft our data.tar.gz...
${TAR_BIN} --hard-dereference --owner root --group root --transform 's,^src/,,S' --transform 's,^,/var/local/,S' -cvzf data.tar.gz ../src/system ../src/wan ../src/payload

# Remove package specific temp stuff
rm -rf ../src/system ../src/wan

# Move our data package
mv -f *.tar.gz ../

## Uninstall
# Copy the script to our working directory, to avoid storing crappy paths in the update package
ln -f ../src/uninstall.sh ./

# Build the uninstall package
kindletool create ota2 "${KT_PM_FLAGS[@]}" -d touch -d paperwhite -d paperwhite2 -d basic -d voyage -d paperwhite3 -d oasis -d basic2 -d oasis2 -d paperwhite4 -d basic3 -d oasis3 libotautils5 uninstall.sh Update_${PKGNAME}_${PKGVER}_uninstall.bin

# Remove package specific temp stuff
rm -f ./uninstall.sh

# Move our update
mv -f *.bin ../


### FW 5.1.x to 5.2.0
# Credits goes to yifanlu & ixtab for pretty much everything, I just adapted the delivery method to FW 5.1.0, and pruned K4 support from the payload. (http://yifan.lu/p/kindle-touch-jailbreak/)
# NOTE: We use yifan's payload, it requires a reboot less than the fixup stuff ;)
###

## Install
# Prepare the directory layout for our data.tar.gz...
mkdir -p ../src/system ../src/wan

# Copy our payload
ln -f ../src/install.sh ../src/system/mntus.params
ln -f ../src/install.sh ../src/wan/info
# Install the bridge, too
ln -f ../src/bridge.sh ../src/system/fixup

# Craft our data.tar.gz...
${TAR_BIN} --hard-dereference --owner root --group root --transform 's,^src/,,S' --transform 's,^,/var/local/,S' -cvzf data.tar.gz ../src/system ../src/wan ../src/payload

# Package our payload tarball :)
kindletool create ota -u -d k5w data.tar.gz data.stgz
#kindletool create recovery -u -d k5w data.tar.gz data.stgz
#kindletool create ota2 -u -d kindle5 data.tar.gz data.stgz

# Remove package specific temp stuff
rm -rf ../src/system ../src/wan data.tar.gz

# Move our data package
mv -f *.stgz ../

## Uninstall (Nothing specific, use the 5.0.x package)


###
# Bridge (Used to carry over the JailBreak during full rootfs updates, like 5.3.0)
###
# Copy the script to our working directory, to avoid storing crappy paths in the update package
ln -f ../src/install-bridge.sh ./
# Kill the file extension to avoid flagging it as an update script ;)
ln -f ../src/bridge.sh ./bridge
# Copy the dispatch script to our working directory, to avoid storing crappy paths in the update package
ln -f ../src/install-dispatch.sh ./
# Kill the file extension to avoid flagging it as an update script ;)
ln -f ../src/dispatch.sh ./dispatch

# Build the install package
kindletool create ota2 "${KT_PM_FLAGS[@]}" -d touch -d paperwhite -d paperwhite2 -d basic -d voyage -d paperwhite3 -d oasis -d basic2 -d oasis2 -d paperwhite4 -d basic3 -d oasis3 libotautils5 install-bridge.sh bridge json_simple-1.1.jar developer.keystore gandalf bridge.conf install-dispatch.sh dispatch fbink Update_${PKGNAME}_bridge_${PKGVER}_install.bin

# Remove package specific temp stuff
rm -f ./install-bridge.sh ./bridge ./install-dispatch.sh ./dispatch

# Move our update
mv -f *.bin ../


###
# Hotfix (Used to re-apply the full JB when only our pubkey is left/available)
###
# Copy the bridge script to our working directory, to avoid storing crappy paths in the update package
ln -f ../src/install-bridge.sh ./
# Kill the file extension to avoid flagging it as an update script ;)
ln -f ../src/bridge.sh ./bridge
# Copy the dispatch script to our working directory, to avoid storing crappy paths in the update package
ln -f ../src/install-dispatch.sh ./
# Kill the file extension to avoid flagging it as an update script ;)
ln -f ../src/dispatch.sh ./dispatch

# Build the install package
kindletool create ota2 -d touch -d paperwhite -d paperwhite2 -d basic -d voyage -d paperwhite3 -d oasis -d basic2 -d oasis2 -d paperwhite4 -d basic3 -d oasis3 -O libotautils5 install-bridge.sh bridge json_simple-1.1.jar developer.keystore gandalf bridge.conf install-dispatch.sh dispatch fbink Update_${PKGNAME}_hotfix_${PKGVER}_install.bin

# Remove package specific temp stuff
rm -f ./install-bridge.sh ./bridge ./install-dispatch.sh ./dispatch

# Move our update
mv -f *.bin ../


### FW 5.x to 5.4.4.2
# Credits goes to yossarian17 for the fantastic delivery method ;). The payload is a trimmed down version of the previous stuff. (http://www.mobileread.com/forums/showthread.php?t=227532)
###

## We need a dummy update package, so build one that'll run on the whole range of targetted device
touch w00t
kindletool create ota2 -d touch -d paperwhite -d paperwhite2 w00t Update_jb.bin

# We of course need our install script...
ln -f ../src/5.4-install.sh ./jb.sh
# And the bridge...
ln -f ../src/bridge.sh ./bridge.sh

# Craft our update package...
mv -f Update_jb.bin 'Update_jb_$(cd mnt && cd us && sh jb.sh).bin'

# Package it (w/ persistent MKK)...
7z a -tzip kindle-5.4-jailbreak.zip ./jb.sh ./bridge.sh ./json_simple-1.1.jar ./developer.keystore ./gandalf ./bridge.conf ./*.bin

# Also build a package compatible with yossarian's launcher :)
ln -f ../src/5.4-install.sh ./jailbreak.sh
# Tweak the cleanup function accordingly
perl -pi -e 's/jb\.sh/jailbreak\.sh/g' ./jailbreak.sh
# And the poisoning...
mv -f 'Update_jb_$(cd mnt && cd us && sh jb.sh).bin' 'Update_jb_$(cd mnt && cd us && sh jailbreak.sh).bin'
# And a README...
echo "See http://www.mobileread.com/forums/showthread.php?t=186645 & http://www.mobileread.com/forums/showthread.php?t=227532 for more info :)" > ./JB-README
echo "" >> ./JB-README
cat ../README >> ./JB-README
# And finally, package it
7z a -tzip kindle-yossarian-jb.zip ./jailbreak.sh ./bridge.sh ./json_simple-1.1.jar ./developer.keystore ./gandalf ./bridge.conf ./*.bin ./JB-README

###
# Emergency bridge recovery
###

# We'll need the bridge (script + job), should both already be taken care of
# And if course, the emergency script itself, usable as both a RUNME or a bridge job emergency script...
ln -f ../src/install-emergency.sh ./emergency.sh
ln -f ../src/install-emergency.sh ./RUNME.sh

# And finally, package it
7z a -tzip emergency-bridge-recovery.zip ./bridge.conf ./bridge.sh ./emergency.sh ./RUNME.sh

# Remove package specific temp stuff
rm -f ./w00t ./jb.sh ./bridge.sh ./*.bin ./jailbreak.sh ./json_simple-1.1.jar ./developer.keystore ./gandalf ./bridge.conf ./JB-README ./emergency.sh ./RUNME.sh

# Move our packages
mv -f *.zip ../


