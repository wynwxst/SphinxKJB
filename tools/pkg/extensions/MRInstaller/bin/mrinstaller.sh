#!/bin/sh
##
#
#  MR Package Installer
#
#  $Id: mrinstaller.sh 18331 2021-03-25 17:16:14Z NiLuJe $
#
##

# Remember our current revision for logging purposes...
MRPI_REV="$( echo '$Revision: 18331 $' | cut -d ' ' -f 2 )"

## Logging
# Pull some helper functions for logging
_FUNCTIONS=/etc/upstart/functions
if [ -f ${_FUNCTIONS} ] ; then
	source ${_FUNCTIONS}
else
	# legacy...
	_FUNCTIONS=/etc/rc.d/functions
	[ -f ${_FUNCTIONS} ] && source ${_FUNCTIONS}
fi

# Are we on FW 5.x?
IS_K5="true"
if [ -f "/etc/rc.d/functions" ] && grep -q "EIPS" "/etc/rc.d/functions" ; then
	IS_K5="false"
fi
# We'll also need to know our device ID...
kmodel="??"

## Check if we're a K5
check_is_touch_device()
{
	[ "${IS_K5}" == "true" ] && return 0

	# We're not!
	return 1
}

# Logging...
logmsg()
{
	if check_is_touch_device ; then
		# Adapt the K5 logging calls to the simpler legacy syntax
		f_log "${1}" "mr_installer" "${2}" "${3}" "${4}"
	else
		# Slightly tweaked version of msg() (from ${_FUNCTIONS}, where the constants are defined)
		local _NVPAIRS
		local _FREETEXT
		local _MSG_SLLVL
		local _MSG_SLNUM

		_MSG_LEVEL="${1}"
		_MSG_COMP="${2}"

		{ [ $# -ge 4 ] && _NVPAIRS="${3}" && shift ; }

		_FREETEXT="${3}"

		eval _MSG_SLLVL=\${MSG_SLLVL_$_MSG_LEVEL}
		eval _MSG_SLNUM=\${MSG_SLNUM_$_MSG_LEVEL}

		local _CURLVL

		{ [ -f ${MSG_CUR_LVL} ] && _CURLVL=$(cat ${MSG_CUR_LVL}) ; } || _CURLVL=1

		if [ ${_MSG_SLNUM} -ge ${_CURLVL} ] ; then
			/usr/bin/logger -p local4.${_MSG_SLLVL} -t "mr_installer" "${_MSG_LEVEL} def:${_MSG_COMP}:${_NVPAIRS}:${_FREETEXT}"
		fi

		[ "${_MSG_LEVEL}" != "D" ] && echo "mr_installer: ${_MSG_LEVEL} def:${_MSG_COMP}:${_NVPAIRS}:${_FREETEXT}"
	fi
}

# From libotautils[5], adapted from libkh[5]
do_fbink_print()
{
	# We need at least two args
	if [ $# -lt 2 ] ; then
		logmsg "W" "do_fbink_print" "" "not enough arguments passed to do_fbink_print ($# while we need at least 2)"
		return 1
	fi

	kh_string="${1}"
	kh_y_shift_up="${2}"

	# Unlike eips, we need at least a single space to even try to print something ;).
	if [ "${kh_string}" == "" ] ; then
		kh_string=" "
	fi

	# Check if we asked for a highlighted message...
	if [ "${3}" == "h" ] ; then
		fbink_extra_args="h"
	else
		fbink_extra_args=""
	fi

	# NOTE: FBInk will handle the padding. FBInk's default font is square, not tall like eips,
	#       so we compensate by tweaking the baseline ;).
	${FBINK_BIN} -qpm${fbink_extra_args} -y $(( -4 - kh_y_shift_up )) "${kh_string}"
}

print_bottom_centered()
{
	# We need at least two args
	if [ $# -lt 2 ] ; then
		logmsg "W" "print_bottom_centered" "" "not enough arguments passed to print_bottom_centered ($# while we need at least 2)"
		return 1
	fi

	kh_string="${1}"
	kh_y_shift_up="${2}"

	# Log it, too
	logmsg "I" "print_bottom_centered" "" "${kh_string}"

	# Sleep a tiny bit to workaround the logic in the 'new' (K4+) eInk controllers that tries to bundle updates
	if [ "${PRINT_SLEEP}" == "true" ] ; then
		usleep 150000	# 150ms
	fi

	do_fbink_print "${kh_string}" "${kh_y_shift_up}"
}

## Check if arg is an int
is_integer()
{
	# Cheap trick ;)
	[ "${1}" -eq "${1}" ] 2>/dev/null
	return $?
}

## Compute our current OTA version (NOTE: Pilfered from Helper's device_id.sh ;))
compute_current_ota_version()
{
	fw_build_maj="$(awk '/Version:/ { print $NF }' /etc/version.txt | awk -F- '{ print $NF }')"
	fw_build_min="$(awk '/Version:/ { print $NF }' /etc/version.txt | awk -F- '{ print $1 }')"
	# Legacy major versions used to have a leading zero, which is stripped from the complete build number. Except on really ancient builds, that (or an extra) 0 is always used as a separator between maj and min...
	fw_build_maj_pp="${fw_build_maj#0}"
	# That only leaves some weird diags build that handle this stuff in potentially even weirder ways to take care of...
	if [ "${fw_build_maj}" -eq "${fw_build_min}" ] ; then
		# Weird diags builds... (5.0.0)
		fw_build="${fw_build_maj_pp}0???"
	else
		# Most common instance... maj#6 + 0 + min#3 or maj#5 + 0 + min#3 (potentially with a leading 0 stripped from maj#5)
		if [ ${#fw_build_min} -eq 3 ] ; then
			fw_build="${fw_build_maj_pp}0${fw_build_min}"
		else
			# Truly ancient builds... For instance, 2.5.6, which is maj#5 + min#4 (with a leading 0 stripped from maj#5)
			fw_build="${fw_build_maj_pp}${fw_build_min}"
		fi
	fi
}

# Our packages live in a specific directory
MRPI_PKGDIR="/mnt/us/mrpackages"
# We're using our own tmpfs
MRPI_TMPFS="/var/tmp/mrpi"
# We're working in a staging directory, in our tmpfs
MRPI_WORKDIR="${MRPI_TMPFS}/staging"
# We're making KindleTool use our own tmpfs as a temp directory
MRPI_TMPDIR="${MRPI_TMPFS}/tmpdir"

## Call kindletool with the right environment setup
MRINSTALLER_BINDIR="$(dirname "$(realpath "${0}")")"
MRINSTALLER_BASEDIR="${MRINSTALLER_BINDIR%*/bin}"
run_kindletool()
{
	# Check that our binary actually is available...
	if [ ! -x "${MRINSTALLER_BASEDIR}/bin/${BINARIES_TC}/kindletool" ] ; then
		print_bottom_centered "No KindleTool binary, aborting" 1
		echo -e "\nCould not find a proper KindleTool binary for the current arch (${BINARIES_TC}), aborting . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		return 1
	fi

	# Pick up our own libz build...
	env KT_WITH_UNKNOWN_DEVCODES="true" TMPDIR="${MRPI_TMPDIR}" LD_LIBRARY_PATH="${MRINSTALLER_BASEDIR}/lib/${BINARIES_TC}" ${MRINSTALLER_BASEDIR}/bin/${BINARIES_TC}/kindletool "$@"
}

# Default to something that won't horribly blow up...
FBINK_BIN="true"
ICON_SIZE="450"
check_fbink()
{
	# Pick the right binary for our device...
	MACHINE_ARCH="$(uname -m)"
	if [ "${MACHINE_ARCH}" == "armv7l" ] ; then
		# NOTE: Slightly crappy Wario/Rex & Zelda detection ;p
		if grep -e '^Hardware' /proc/cpuinfo | grep -q -e 'i\.MX[[:space:]]\?[6-7]' ; then
			BINARIES_TC="PW2"
		else
			BINARIES_TC="K5"
		fi
	else
		BINARIES_TC="K3"
	fi

	# Check if we have a tarball of binaries to install...
	if [ -f "${MRINSTALLER_BASEDIR}/data/mrpi-${BINARIES_TC}.tar.gz" ] ; then
		# Clear existing binaries...
		for tc_set in K3 K5 PW2 ; do
			for bin_set in lib bin ; do
				for file in ${MRINSTALLER_BASEDIR}/${bin_set}/${tc_set}/* ; do
					[ -f "${file}" ] && rm -f "${file}"
				done
			done
		done
		tar -xvzf "${MRINSTALLER_BASEDIR}/data/mrpi-${BINARIES_TC}.tar.gz" -C "${MRINSTALLER_BASEDIR}"
		# Clear data folder now
		for file in ${MRINSTALLER_BASEDIR}/data/mrpi-*.tar.gz ; do
			[ -f "${file}" ] && rm -f "${file}"
		done
	fi

	# Check that our binary actually is available...
	if [ ! -x "${MRINSTALLER_BASEDIR}/bin/${BINARIES_TC}/fbink" ] ; then
		print_bottom_centered "No FBInk binary, aborting" 1
		echo -e "\nCould not find a proper FBInk binary for the current arch (${BINARIES_TC}), aborting . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		return 1
	fi

	# We're good, set it up...
	FBINK_BIN="${MRINSTALLER_BASEDIR}/bin/${BINARIES_TC}/fbink"

	# And use it to pickup our device ID, and a few things we'll need to compute the ideal icon size...
	eval "$(${FBINK_BIN} -e | tr ';' '\n' | grep -e viewHeight -e FONTH -e deviceId | tr '\n' ';')"
	# And convert the deviceID to hex, as that's what KindleTool reports...
	if [ ${deviceId} -gt 255 ] ; then
		kmodel="$(printf "%03X" "${deviceId}")"
	else
		kmodel="$(printf "%02X" "${deviceId}")"
	fi

	# Compute the ideal icon size, knowing that we'll print it in the center of the screen,
	# and we need 8 rows of text on the bottom, plus two of padding...
	ICON_SIZE="$(( viewHeight - (10 * FONTH * 2) ))"
	# Double check that it's sane
	is_integer "${ICON_SIZE}" || ICON_SIZE="450"

	return 0
}

## Display an icon in the middle of the screen
print_icon()
{
	# We need at least one arg
	if [ $# -lt 1 ] ; then
		logmsg "W" "print_icon" "" "not enough arguments passed to print_icon ($# while we need at least 1)"
		return 1
	fi

	kh_icon="${1}"

	# Log it, too
	logmsg "I" "print_icon" "" "${kh_icon}"

	# Which one did we want?
	case "${kh_icon}" in
		"OK" )
			kh_icon_cp=""	# \uf633
		;;
		"FAIL" )
			kh_icon_cp=""	# \uf071
		;;
		"BOMB" )
			kh_icon_cp="ﮏ"	# \ufb8f
		;;
		"WAIT" )
			kh_icon_cp=""	# \uf252
		;;
		"PYTHON" )
			kh_icon_cp=""	# \ue73c
		;;
		"USBNET" )
			kh_icon_cp=""	# \uf68c
		;;
		"BRIDGE" )
			kh_icon_cp=""	# \ue286
		;;
		"AMZ" )
			kh_icon_cp=""	# \uf270
		;;
		"SAD" )
			kh_icon_cp=""	# \uf119
		;;
		"LINUX" )
			kh_icon_cp=""	# \uf17c
		;;
		"HAPPY" )
			kh_icon_cp=""	# \uf118
		;;
		"TOOLS" )
			kh_icon_cp=""	# \uf425
		;;
		"KUAL" )
			kh_icon_cp="異"	# \uf962
		;;
		"MRPI" )
			kh_icon_cp=""	# \uf487
		;;
		* )
			logmsg "W" "print_icon" "" "requested an unknown icon (${kh_icon})"
			return 1
		;;
	esac

	# This is why we needed a custom build: for TTF support ;).
	# Patched font from https://nerdfonts.com/
	${FBINK_BIN} -qMm -t regular="${MRINSTALLER_BASEDIR}/data/BigBlue_Terminal.ttf",px="${ICON_SIZE}" "${kh_icon_cp}"
}

## Rotate the log
rotate_logs()
{
	# If it's over 1MB, compress & timestamp
	if [ -f "${MRINSTALLER_BASEDIR}/log/mrinstaller.log" ] ; then
		log_size="$(stat -c %s "${MRINSTALLER_BASEDIR}/log/mrinstaller.log")"

		if [ ${log_size} -gt $((1 * 1024 * 1024)) ] ; then
			gzip "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			mv "${MRINSTALLER_BASEDIR}/log/mrinstaller.log.gz" "${MRINSTALLER_BASEDIR}/log/mrinstaller-$(date +%Y-%m-%d_%H-%M).log.gz"
		fi
	fi
}

## Check that we have enough free space
enough_free_space()
{
	if [ "$(df -k /mnt/us | awk '$3 ~ /[0-9]+/ { print $4 }')" -lt "$((150 * 1024))" ] ; then
		# Less than 150MB left, meep!
		return 1
	else
		# Good enough!
		return 0
	fi
}

## Check if our own tmpfs is mounted
is_mrpi_tmpfs_up()
{
	if grep -q "^tmpfs ${MRPI_TMPFS} tmpfs " /proc/mounts ; then
		# Peachy :)
		return 0
	fi

	# Huh, it's already up?
	return 1
}

## Compute an estimate of the amount of available memory to resize our tmpfs
resize_mrpi_tmpfs()
{
	logmsg "I" "resize_mrpi_tmpfs" "" "checking available memory"

	# We'll resort to a few different methods, because depending on the age of the Linux kernel,
	# we won't always have access to the easiest of them, which is relying on MemAvailable in /proc/meminfo...
	# c.f., https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773
	if grep -q 'MemAvailable' /proc/meminfo ; then
		# We'll settle for 85% of available memory to leave a bit of breathing room
		tmpfs_size="$(awk '/MemAvailable/ {printf "%d", $2 * 0.85}' /proc/meminfo)"
	elif grep -q 'Inactive(file)' /proc/meminfo ; then
		# Basically try to emulate the kernel's computation, c.f., https://unix.stackexchange.com/q/261247
		# Again, 85% of available memory
		tmpfs_size="$(awk -v low=$(grep low /proc/zoneinfo | awk '{k+=$2}END{printf "%d", k}') \
			'{a[$1]=$2}
			END{
				printf "%d", (a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low))*0.85;
			}' /proc/meminfo)"
	else
		# Ye olde crap workaround of Free + Buffers + Cache...
		# Take it with a grain of salt, and settle for 80% of that...
		tmpfs_size="$(awk \
			'{a[$1]=$2}
			END{
				printf "%d", (a["MemFree:"]+a["Buffers:"]+a["Cached:"])*0.80;
			}' /proc/meminfo)"
	fi

	# Make sure we end up with a sane-ish fallback in case all this failed...
	is_integer "${tmpfs_size}" || tmpfs_size="81920"

	# Log those computations
	logmsg "I" "resize_mrpi_tmpfs" "" "can spare $((tmpfs_size / 1024))MB for mrpi tmpfs"

	# Check that we actually end up with enough free memory to be able to use it...
	# NOTE: The most space-hungry package I have is the legacy variant of USBNet, which currently requires about 46MB.
	#       That said, we should be pretty safe: so far, I've always had *more* available RAM than the ceiling value,
	#       even on the K2, where the ceiling is at ~77MB, and I usually have around ~89MB of available memory to spare!
	if [ "${tmpfs_size}" -lt "$(( 56 * 1024 ))" ] ; then
		# If we can spare less than 56MB, abort!
		logmsg "E" "resize_mrpi_tmpfs" "" "not enough available memory (< 56MB) for mrpi tmpfs!"
		return 1
	fi

	# Compare that with our ceiling, 62.5% of the total memory
	tmpfs_ceil="$(awk '/MemTotal/ {printf "%d", $2 * 0.625}' /proc/meminfo)"
	# With a fallback...
	is_integer "${tmpfs_ceil}" || tmpfs_ceil="81920"

	# If our computed size is smaller than the ceiling value, resize the tmpfs
	if [ "${tmpfs_size}" -lt "${tmpfs_ceil}" ] ; then
		/bin/mount -t tmpfs tmpfs "${MRPI_TMPFS}" -o remount,defaults,size=${tmpfs_size}K,mode=1777,noatime
		if [ $? -ne 0 ] ; then
			logmsg "E" "resize_mrpi_tmpfs" "" "failed to remount mrpi tmpfs!"
			return 1
		fi

		# Even if it appeared to work, double check...
		if ! is_mrpi_tmpfs_up ; then
			logmsg "E" "resize_mrpi_tmpfs" "" "mrpi tmpfs is still not mounted!"
			return 1
		fi

		# Success!
		logmsg "I" "resize_mrpi_tmpfs" "" "resized mrpi tmpfs down to $((tmpfs_size / 1024))MB"
	fi

	return 0
}

## To make things faster, we'll try to do as much work in RAM as possible
## But since none of the existing tmpfs fit our needs, we'll create our own.
mount_mrpi_tmpfs()
{
	logmsg "I" "mount_mrpi_tmpfs" "" "trying to create mrpi tmpfs"

	# Sync first...
	sync

	# Don't do anything if for some strange reason it's already up...
	if is_mrpi_tmpfs_up ; then
		logmsg "W" "mount_mrpi_tmpfs" "" "mrpi tmpfs is already mounted!"
		return 0
	fi

	# Namely, the default ones tend to be small. So let's say we want one that's about 62.5% of the total RAM.
	# That's usually close enough to the free RAM we get with the framework down, and should be more than enough ;).
	tmpfs_size="$(awk '/MemTotal/ {printf "%d", $2 * 0.625}' /proc/meminfo)"
	# Just in case the apocalypse hits, and our awk shenanigans fail, make sure we have sane defaults, even for 128MB of RAM
	is_integer "${tmpfs_size}" || tmpfs_size="81920"

	# Create our mountpoint
	mkdir -p "${MRPI_TMPFS}"

	# And mount it :)
	/bin/mount -t tmpfs tmpfs "${MRPI_TMPFS}" -o defaults,size=${tmpfs_size}K,mode=1777,noatime
	if [ $? -ne 0 ] ; then
		logmsg "E" "mount_mrpi_tmpfs" "" "failed to create mrpi tmpfs!"
		return 1
	fi

	# Even if it appeared to work, double check...
	if ! is_mrpi_tmpfs_up ; then
		logmsg "E" "mount_mrpi_tmpfs" "" "mrpi tmpfs is still not mounted!"
		return 1
	fi

	# Success!
	logmsg "I" "mount_mrpi_tmpfs" "" "created $((tmpfs_size / 1024))MB mrpi tmpfs"
	return 0
}

## And unmount it when we're done...
umount_mrpi_tmpfs()
{
	logmsg "I" "umount_mrpi_tmpfs" "" "trying to unmount mrpi tmpfs"

	# Sync first...
	sync

	/bin/umount "${MRPI_TMPFS}"
	if [ $? -ne 0 ] ; then
		logmsg "E" "umount_mrpi_tmpfs" "" "failed to unmount mrpi tmpfs!"
		return 1
	fi

	# Even if it appeared to work, double check...
	if is_mrpi_tmpfs_up ; then
		logmsg "E" "umount_mrpi_tmpfs" "" "mrpi tmpfs is still mounted!"
		return 1
	fi

	# Success!
	logmsg "I" "umount_mrpi_tmpfs" "" "successfully unmounted mrpi tmpfs"
	return 0
}

## Reimplement mntroot ourselves, because its checks aren't as robust as one would hope...
is_rootfs_ro()
{
	if awk '$4~/(^|,)ro($|,)/' /proc/mounts | grep -q '^/dev/root / ' ; then
		# Peachy :)
		return 0
	fi

	# Hu oh, it's rw...
	return 1
}

is_rootfs_rw()
{
	if awk '$4~/(^|,)rw($|,)/' /proc/mounts | grep -q '^/dev/root / ' ; then
		# Peachy :)
		return 0
	fi

	# Hu oh, it's ro...
	return 1
}

make_rootfs_rw()
{
	logmsg "I" "make_rootfs_rw" "" "trying to remount rootfs rw"

	# Sync first...
	sync

	# Don't do anything if for some strange reason it's already rw...
	if is_rootfs_rw ; then
		logmsg "W" "make_rootfs_rw" "" "rootfs is already rw!"
		return 0
	fi

	# Do eet!
	/bin/mount -o remount,rw /
	if [ $? -ne 0 ] ; then
		logmsg "E" "make_rootfs_rw" "" "failed to remount rootfs rw!"
		return 1
	fi

	# Even if it appeared to work, double check...
	if is_rootfs_ro ; then
		logmsg "E" "make_rootfs_rw" "" "rootfs is still ro after a rw remount!"
		return 1
	fi

	# Success!
	logmsg "I" "make_rootfs_rw" "" "rootfs has been remounted rw"
	return 0
}

make_rootfs_ro()
{
	logmsg "I" "make_rootfs_ro" "" "trying to remount rootfs ro"

	# Sync first...
	sync

	# Don't do anything if for some strange reason it's already ro...
	if is_rootfs_ro ; then
		logmsg "W" "make_rootfs_ro" "" "rootfs is already ro!"
		return 0
	fi

	# Do eet!
	/bin/mount -o remount,ro /
	if [ $? -ne 0 ] ; then
		logmsg "E" "make_rootfs_ro" "" "failed to remount rootfs ro!"
		return 1
	fi

	# Even if it appeared to work, double check...
	if is_rootfs_rw ; then
		logmsg "E" "make_rootfs_ro" "" "rootfs is still rw after a ro remount!"
		return 1
	fi

	# Success!
	logmsg "I" "make_rootfs_ro" "" "rootfs has been remounted ro"
	return 0
}

## Run a single package
run_package()
{
	# We need at one arg
	if [ $# -lt 1 ] ; then
		logmsg "W" "run_package" "" "not enough arguments passed to run_package ($# while we need at least 1)"
		return 1
	fi

	# Clear our five lines...
	print_bottom_centered "" 4
	print_bottom_centered "" 3
	print_bottom_centered "" 2
	print_bottom_centered "" 1
	print_bottom_centered "" 0

	PKG_FILENAME="${1}"

	# Cleanup the name a bit for the screen
	PKG_NAME="${PKG_FILENAME#[uU]pdate[-_]*}"
	# Legacy devices have an older busybox version, with an ash build that sucks even more! [Can't use / substitutions]
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/uninstall/U/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/install/I/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/touch_pw/K5/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3_koa_kt3_koa2_pw4_kt4_koa3/WARIO+ZELDA+REX/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3_koa_kt3_koa2_pw4_kt4/WARIO+ZELDA+REX/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3_koa_kt3_koa2_pw4/WARIO+ZELDA+REX/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3_koa_kt3_koa2/WARIO+ZELDA/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3_koa_kt3/WARIO+/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv_pw3/WARIO/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2_kt2_kv/WARIO/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw2/PW2/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/k2_dx_k3/LEGACY/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/koa2_koa3/ZELDA/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/koa2/ZELDA/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw4_kt4/REX/')"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/pw4/REX/')"
	PKG_NAME="${PKG_NAME%*.bin}"
	PKG_NAME="$(echo "${PKG_NAME}" | sed -e 's/[-_]/ /g')"

	# Start by timestamping our logs...
	echo -e "\n\n**** **** **** ****" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
	echo -e "\n[$(date +'%F @ %T %z')] :: [MRPI r${MRPI_REV}] - Beginning the processing of package '${PKG_FILENAME}' (${PKG_NAME}) . . .\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"

	# Now that the framework is down and we actually have a decent amount of free RAM, try to resize out tmpfs accordingly
	if ! resize_mrpi_tmpfs ; then
		print_bottom_centered "Failed to resize MRPI tmpfs, waiting . . ." 1
		echo -e "\nFailed to resize MRPI tmpfs, waiting . . .\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		sleep 5
		# Try one final time...
		if ! resize_mrpi_tmpfs ; then
			print_icon "FAIL"
			print_bottom_centered "Really failed to resize MRPI tmpfs, skipping" 1
			echo -e "\nReally failed to resize MRPI tmpfs, skipping ${PKG_NAME} . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			sleep 5
			return 1
		fi
	fi

	# Show a possibly relevant icon during processing
	# First, make sure case won't bother us...
	uc_pkg_name="$(echo "${PKG_NAME}" | tr '[a-z]' '[A-Z]')"
	case "${uc_pkg_name}" in
		*PYTHON* )
			pkg_icon="PYTHON"
		;;
		*USBNET* )
			pkg_icon="USBNET"
		;;
		*BRIDGE* | *HOTFIX* )
			pkg_icon="BRIDGE"
		;;
		*KUAL* )
			pkg_icon="KUAL"
		;;
		*CRP* | *RP* )
			pkg_icon="TOOLS"
		;;
		* )
			pkg_icon="WAIT"
		;;
	esac
	# And show it
	print_icon "${pkg_icon}"

	# Check if it's valid...
	print_bottom_centered "Checking ${PKG_NAME}" 4
	# Always re-compute the OTA number, in case something dared to mess with it...
	compute_current_ota_version
	# Save KindleTool's output (Tweak the IFS to make our life easier...)
	BASE_IFS="${IFS}"
	IFS=''
	ktool_output="$(run_kindletool convert -i "${PKG_FILENAME}" 2>&1)"
	mrpi_ret="$?"
	# On the off chance that failed, abort
	# NOTE: One sneaky possibility for this to fail would be an userstore mounted noexec, which might happen if the bridge is broken, as it was during the whole 5.10 debacle...
	if [ ${mrpi_ret} -ne 0 ] ; then
		IFS="${BASE_IFS}"
		print_icon "FAIL"
		print_bottom_centered "Failed to parse package, skipping" 1
		echo -e "\nFailed to parse package '${PKG_FILENAME}' (${PKG_NAME}) [return code: ${mrpi_ret}], skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		echo -e "\nKindleTool output:\n${ktool_output}\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		return 1
	fi
	# Check bundle type
	PKG_BUNDLE_TYPE="$(echo ${ktool_output} | sed -n -r 's/^(Bundle Type)([[:blank:]]*)(.*?)$/\3/p')"
	case "${PKG_BUNDLE_TYPE}" in
		"OTA V1" )
			PKG_PADDING_BYTE="$(echo ${ktool_output} | sed -n -r 's/^(Padding Byte)([[:blank:]]*)([[:digit:]]*)( \()(.*?)(\))$/\5/p')"
			PKG_DEVICE_CODE="$(echo ${ktool_output} | sed -n -r '/^(Device)([[:blank:]]*)(.*?)$/p' | sed -n -r -e 's/^(Device)([[:blank:]]*)(.*?)(\()//' -e 's/((([[:xdigit:]GHJKLMNPQRSTUVWX]{3})( -> 0x)([[:xdigit:]]{3}))|((0x)([[:xdigit:]]{2})))(\))(.*?)$/\5\8/p')"
			PKG_MIN_OTA="$(echo ${ktool_output} | sed -n -r 's/^(Minimum OTA)([[:blank:]]*)([[:digit:]]*)$/\3/p')"
			PKG_MAX_OTA="$(echo ${ktool_output} | sed -n -r 's/^(Target OTA)([[:blank:]]*)([[:digit:]]*)$/\3/p')"
			# Now that we're done with KindleTool's output, restore our original IFS value...
			IFS="${BASE_IFS}"

			# Check padding byte
			case "${PKG_PADDING_BYTE}" in
				"0x13" | "0x00" )
					is_mr_package="true"
				;;
				* )
					is_mr_package="false"
				;;
			esac
			# Reject non-MR packages
			if [ "${is_mr_package}" == "false" ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not an MR package, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not an MR package, skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi

			# Check device code
			if [ "${kmodel}" != "${PKG_DEVICE_CODE}" ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not targeting your device, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not targeting your device [${kmodel} vs. ${PKG_DEVICE_CODE}], skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi

			# Version check... NOTE: Busybox (and Bash < 3) stores ints as int_32_t (i.e., signed 32bit), so we have to get creative to avoid overflows... >_<. We don't have access to bc, so rely on awk...
			if [ "$(awk -v fw_build="${fw_build}" -v PKG_MIN_OTA="${PKG_MIN_OTA}" -v PKG_MAX_OTA="${PKG_MAX_OTA}" 'BEGIN { print (fw_build < PKG_MIN_OTA || fw_build >= PKG_MAX_OTA) }')" -ne 0 ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not targeting your FW version, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not targeting your FW version [!(${PKG_MIN_OTA} <= ${fw_build} < ${PKG_MAX_OTA})], skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi
		;;
		"OTA V2" )
			PKG_CERT_NUM="$(echo ${ktool_output} | sed -n -r 's/^(Cert number)([[:blank:]]*)(.*?)$/\3/p')"
			PKG_DEVICES_CODES="$(echo ${ktool_output} | sed -n -r '/^(Device)([[:blank:]]*)(.*?)$/p' | sed -n -r -e 's/^(Device)([[:blank:]]*)(.*?)(\()//' -e 's/((([[:xdigit:]GHJKLMNPQRSTUVWX]{3})( -> 0x)([[:xdigit:]]{3}))|((0x)([[:xdigit:]]{2})))(\))(.*?)$/\5\8/p')"
			PKG_MIN_OTA="$(echo ${ktool_output} | sed -n -r 's/^(Minimum OTA)([[:blank:]]*)([[:digit:]]*)$/\3/p')"
			PKG_MAX_OTA="$(echo ${ktool_output} | sed -n -r 's/^(Target OTA)([[:blank:]]*)([[:digit:]]*)$/\3/p')"
			# Now that we're done with KindleTool's output, restore our original IFS value...
			IFS="${BASE_IFS}"

			# Check signing cert to reject non-MR packages
			if [ "${PKG_CERT_NUM}" -ne 0 ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not an MR package, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not an MR package, skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi

			# Check device codes
			devcode_match="false"
			for cur_devcode in ${PKG_DEVICES_CODES} ; do
				if [ "${kmodel}" == "${cur_devcode}" ] ; then
					devcode_match="true"
				fi
			done
			if [ "${devcode_match}" == "false" ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not targeting your device, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not targeting your device [${kmodel} vs. $(echo ${PKG_DEVICES_CODES} | tr -s '\\n' ' ')], skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi

			# Version check... NOTE: Busybox (and Bash < 3) stores ints as int_32_t, so we have to get creative to avoid overflows... >_<. We don't have access to bc, so rely on awk...
			if [ "$(awk -v fw_build="${fw_build}" -v PKG_MIN_OTA="${PKG_MIN_OTA}" -v PKG_MAX_OTA="${PKG_MAX_OTA}" 'BEGIN { print (fw_build < PKG_MIN_OTA || fw_build > PKG_MAX_OTA) }')" -ne 0 ] ; then
				print_icon "FAIL"
				print_bottom_centered "Not targeting your FW version, skipping" 1
				echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not targeting your FW version [!(${PKG_MIN_OTA} < ${fw_build} < ${PKG_MAX_OTA})] skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				return 1
			fi
		;;
		* )
			IFS="${BASE_IFS}"

			print_icon "FAIL"
			print_bottom_centered "Not an OTA package, skipping" 1
			echo -e "\nPackage '${PKG_FILENAME}' (${PKG_NAME}) is not an OTA package [${PKG_BUNDLE_TYPE}], skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			return 1
		;;
	esac

	# Start it up...
	print_bottom_centered "* ${PKG_NAME} *" 4

	# Clear workdir, and extract package in it
	rm -rf "${MRPI_WORKDIR}"
	if ! enough_free_space ; then
		print_icon "FAIL"
		print_bottom_centered "Not enough free space left, skipping" 1
		echo -e "\nNot enough space left to process ${PKG_NAME}, skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		return 1
	fi
	# NOTE: Using >> LOG 2>&1 will truncate the log before storing KindleTool's output, for some mysterious reason...
	#       But this works (as does using tee -a).
	run_kindletool extract "${PKG_FILENAME}" "${MRPI_WORKDIR}" 2>> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
	# KindleTool handles the integrity checking for us, so let's check that this went fine...
	if [ $? -ne 0 ] ; then
		print_icon "FAIL"
		print_bottom_centered "Failed to extract package, skipping" 1
		echo -e "\nFailed to extract package '${PKG_FILENAME}' (${PKG_NAME}), skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		return 1
	fi
	# We can then remove the package itself
	rm -f "${PKG_FILENAME}"

	# Make the rootfs rw...
	if ! make_rootfs_rw ; then
		print_bottom_centered "Failed to remount rootfs RW, waiting . . ." 1
		echo -e "\nFailed to remount rootfs RW, waiting . . .\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		sleep 5
		# Try one final time...
		if ! make_rootfs_rw ; then
			print_icon "FAIL"
			print_bottom_centered "Really failed to remount rootfs RW, skipping" 1
			echo -e "\nReally failed to remount rootfs RW, skipping ${PKG_NAME} . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			sleep 5
			return 1
		fi
	fi

	# Run the package scripts in alphabetical order, from inside our workdir...
	cd "${MRPI_WORKDIR}"
	RAN_SOMETHING="false"
	FAILED_SOMETHING="false"
	# NOTE: We only handle toplevel scripts
	for pkg_script in *.sh *.ffs ; do
		if [ -f "./${pkg_script}" ] ; then
			RAN_SOMETHING="true"
			print_bottom_centered "Running ${pkg_script} . . ." 3
			# Log what the script does...
			echo -e "--\nRunning '${pkg_script}' for '${PKG_NAME}' (${PKG_FILENAME}) @ $(date -R)\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			# Abort at the first sign of trouble...
			if check_is_touch_device ; then
				/bin/sh -e "./${pkg_script}" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log" 2>&1
				# Catch errors...
				mrpi_ret="$?"
			else
				# NOTE: Unfortunately, on legacy devices, actually sourcing /etc/rc.d/functions will fail, so we can't use -e here... >_<"
				/bin/sh "./${pkg_script}" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log" 2>&1
				# On the off-chance it'd actually be useful then, keep catching errors...
				mrpi_ret="$?"
			fi
			if [ ${mrpi_ret} -ne 0 ] ; then
				FAILED_SOMETHING="true"
				print_icon "FAIL"
				print_bottom_centered "Package script failed (${mrpi_ret}), moving on . . . :(" 1
				echo -e "\nHu oh... Got return code ${mrpi_ret} . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
				# Leave time to the user to read it...
				sleep 10
			else
				print_bottom_centered "Success. :)" 1
				echo -e "\nSuccess! :)\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			fi
		fi
	done
	# Warn if no scripts were found
	if [ "${RAN_SOMETHING}" == "false" ] ; then
		print_icon "BOMB"
		print_bottom_centered "No scripts were found, skipping" 1
		echo -e "\nNo scripts were found, skipping . . . :(\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		sleep 5
	else
		# NOTE: While we show a FAIL icon ASAP when *any* script fails,
		#       we only show an OK checkmark at the end of *every* script,
		#       provided none of them failed.
		if [ ${mrpi_ret} -eq 0 ] && [ "${FAILED_SOMETHING}" == "false" ] ; then
			print_icon "OK"
		fi
	fi
	# And get out of the staging directory once we're done.
	cd "${MRPI_PKGDIR}"

	# Lock the rootfs down
	if ! make_rootfs_ro ; then
		print_bottom_centered "Failed to remount rootfs RO, waiting . . ." 1
		echo -e "\nFailed to remount rootfs RO, waiting . . .\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
		sleep 5
		# Try one final time...
		if ! make_rootfs_ro ; then
			print_icon "BOMB"
			print_bottom_centered "Really failed to remount rootfs RO -_-" 1
			echo -e "\nReally failed to remount rootfs RO -_-\n" >> "${MRINSTALLER_BASEDIR}/log/mrinstaller.log"
			sleep 5
		fi
	fi

	# Clean up behind us
	rm -rf "${MRPI_WORKDIR}"

	return 0
}

## Go!
launch_installer()
{
	# Check for FBInk, and refresh binaries if need be...
	if ! check_fbink ; then
		print_bottom_centered "Couldn't setup binaries, aborting." 1
		return 1
	fi

	# Sleep a while to let KUAL die
	print_bottom_centered "Hush, little baby . . ." 1
	sleep 5

	# NOTE: Fugly FW 5.6.1 handling. Die *before* stopping the UI if we're not root, because we might not be able to bring it back up otherwise.
	if [ "$(id -u)" -ne 0 ] ; then
		print_bottom_centered "Unprivileged user, aborting." 1
		return 1
	fi

	# Let's do this!
	print_icon "MRPI"
	print_bottom_centered "Launching the MR installer . . ." 1

	# Rotate the logs if need be
	rotate_logs

	# Move to our package directory...
	mkdir -p "${MRPI_PKGDIR}"
	cd "${MRPI_PKGDIR}"

	# Loop over packages...
	for pkg in *.bin ; do
		# Check that we actually have some
		if [ -f "${pkg}" ] ; then
			# Try to build a list of packages, while honoring a modicum of dependency tree
			case "${pkg}" in
				*usbnet*install* )
					# Top priority
					MR_PKGS_HEAD_LIST="${pkg} ${MR_PKGS_HEAD_LIST}"
				;;
				*jailbreak*uninstall* )
					# Lowest priority
					MR_PKGS_TAIL_LIST="${MR_PKGS_TAIL_LIST} ${pkg}"
				;;
				*jailbreak*install* )
					# High priority
					MR_PKGS_HEAD_LIST="${MR_PKGS_HEAD_LIST} ${pkg}"
				;;
				*mkk*install* )
					# High priority
					MR_PKGS_HEAD_LIST="${MR_PKGS_HEAD_LIST} ${pkg}"
				;;
				*python*install* )
					# High priority
					MR_PKGS_HEAD_LIST="${MR_PKGS_HEAD_LIST} ${pkg}"
				;;
				*_rp_*install* | *_rescue_pack* )
					# High priority
					MR_PKGS_HEAD_LIST="${MR_PKGS_HEAD_LIST} ${pkg}"
				;;
				* )
					# Normal priority
					MR_PKGS_LIST="${MR_PKGS_LIST} ${pkg}"
				;;
			esac
		else
			# No packages were found, go away
			print_bottom_centered "No MR packages found" 1
			return 1
		fi
	done

	# Construct our final package list
	MR_PKGS_LIST="${MR_PKGS_HEAD_LIST} ${MR_PKGS_LIST} ${MR_PKGS_TAIL_LIST}"

	# Try to setup our tmpfs
	if ! mount_mrpi_tmpfs ; then
		print_bottom_centered "Failed to create MRPI tmpfs, waiting . . ." 1
		sleep 5
		# Try one final time...
		if ! mount_mrpi_tmpfs ; then
			print_bottom_centered "Really failed to create MRPI tmpfs, aborting." 1
			sleep 5
			return 1
		fi
	fi
	mkdir -p "${MRPI_TMPDIR}"

	# Don't get killed!
	trap "" SIGTERM

	# Bring down most of the services
	if check_is_touch_device ; then
		stop x
		# Let's settle down a bit...
		sleep 5
		# If AcXE is installed, stop it (it doesn't depend on the UI, and thus would still be up)
		if [ -f "/etc/upstart/acxe.conf" ] ; then
			# Check if it's up...
			if [ "$(status acxe)" == "acxe start/running" ] ; then
				stop acxe
				# Shouldn't happen...
				if [ $? -ne 0 ] ; then
					print_bottom_centered "Failed to stop AcXE -_-" 1
					sleep 2
				fi
			fi
		fi
	else
		# This is going to get ugly... Clear the screen
		${FBINK_BIN} -c
		# If we're in USBNet mode, down it manually first, because we might need volumd to tear it down, which we won't have in single-user mode...
		# See the comments in USBNetwork itself related to volumd for the details on why we can't really keep it up during an update (TL;DR: it breaks usbms exports)...
		# NOTE: We need these shenanigans with custom services because we usually don't install the proper symlinks for the single-user runlevel... ;).
		if [ -f "/etc/init.d/usbnet" ] ; then
			# Do this unconditionally, the script is smart enough to figure out the rest ;).
			/etc/init.d/usbnet stop
		fi
		# Switch to single-user
		telinit 1
		# Reprint our message after the clear...
		sleep 2
		print_icon "MRPI"
		print_bottom_centered "Launching the MR installer . . ." 1
		# Wait for everything to go down...
		sleep 20
		# Re-up syslog
		/etc/init.d/syslog-ng start

		# And down most of the custom stuff...
		# Start by listing everything that goes down when updating...
		for service in /etc/rc3.d/K* ; do
			UPDATE_RUNLEVEL_KILLS="${UPDATE_RUNLEVEL_KILLS} ${service##*/}"
		done
		# And everything that goes down in single-user mode...
		for service in /etc/rc1.d/K* ; do
			SINGLEU_RUNLEVEL_KILLS="${SINGLEU_RUNLEVEL_KILLS} ${service##*/}"
		done
		# Manually down anything that the updater runlevel downs, but not single-user...
		for cur_service in ${UPDATE_RUNLEVEL_KILLS} ; do
			is_custom="true"
			for service in ${SINGLEU_RUNLEVEL_KILLS} ; do
				if [ "${cur_service}" == "${service}" ] ; then
					is_custom="false"
				fi
			done
			# Is it *really* custom?
			if [ "${is_custom}" == "true" ] ; then
				# Don't store USBNet, we're handling it manually
				if [ "$(echo ${cur_service} | tail -c +4)" != "usbnet" ] ; then
					# Store the list of custom services without their order prefix...
					CUSTOM_SERVICES_LIST="${CUSTOM_SERVICES_LIST} $(echo ${cur_service} | tail -c +4)"
				fi
			fi
		done

		# And down them!
		for service in ${CUSTOM_SERVICES_LIST} ; do
			if [ -f "/etc/init.d/${service}" ] ; then
				/etc/init.d/${service} stop
			fi
		done

		# let's wait a bit more...
		sleep 7
	fi

	# Sync FS
	sync

	# Blank the screen
	${FBINK_BIN} -c

	# Say hi (again)
	print_icon "MRPI"

	# And install our packages in order, one by one...
	for cur_pkg in ${MR_PKGS_LIST} ; do
		if [ -f "${cur_pkg}" ] ; then
			run_package "${cur_pkg}"
			# Remove package in case of failure...
			if [ $? -ne 0 ] ; then
				print_bottom_centered "Destroying package . . ." 1
				rm -f "${cur_pkg}"
				# Don't leave a staging directory behind us, we might have failed without clearing it...
				rm -rf "${MRPI_WORKDIR}"
				# Try to avoid leaving a rw rootfs, we might have failed with it still rw...
				if ! make_rootfs_ro ; then
					print_bottom_centered "Failed to remount rootfs RO, waiting . . ." 1
					sleep 5
					# Try one final time...
					if ! make_rootfs_ro ; then
						print_bottom_centered "Really failed to remount rootfs RO -_-" 1
						sleep 5
					fi
				fi
				sleep 2
			fi
		else
			# Should never happen...
			print_bottom_centered "${cur_pkg} is not a file, skipping" 1
		fi
	done

	# Sync FS
	sync

	# Try to unmount our tmpfs
	rm -rf "${MRPI_TMPDIR}"
	if ! umount_mrpi_tmpfs ; then
		print_bottom_centered "Failed to unmount MRPI tmpfs, waiting . . ." 1
		sleep 5
		# Try one final time...
		if ! umount_mrpi_tmpfs ; then
			print_bottom_centered "Really failed to unmount MRPI tmpfs -_-" 1
			sleep 5
		fi
	fi

	# We're done! Sleep between print calls in order to avoid losing our last message...
	print_icon "AMZ"
	PRINT_SLEEP="true"
	print_bottom_centered "" 4
	print_bottom_centered "" 3
	print_bottom_centered "" 2
	print_bottom_centered "Done, restarting UI . . ." 1
	print_bottom_centered "" 0
	sleep 2

	# Bring the UI back up!
	if check_is_touch_device ; then
		# If we still have AcXE installed, restart it
		if [ -f "/etc/upstart/acxe.conf" ] ; then
			# Check if it's down...
			if [ "$(status acxe)" == "acxe stop/waiting" ] ; then
				start acxe
				# Shouldn't happen...
				if [ $? -ne 0 ] ; then
					print_bottom_centered "Failed to start AcXE -_-" 1
					sleep 2
				else
					sleep 1
				fi
			fi
		fi
		start x
	else
		# Thankfully enough, we don't have to jump through any hoops this time ;).
		telinit 5
	fi
}

# Main
case "${1}" in
	"launch_installer" )
		${1}
	;;
	* )
		print_bottom_centered "invalid action (${1})" 1
	;;
esac

return 0
