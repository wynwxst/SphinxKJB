#!/bin/sh
#
# Kindle Touch JailBreak Install
# Heavily based on stuff created by Yifan Lu <http://yifan.lu/>
#
# $Id: install.sh 17337 2020-05-17 17:39:34Z NiLuJe $
#
##

JAILBREAK_PAYLOAD="/var/local/payload"
JAILBREAK_KEY="${JAILBREAK_PAYLOAD}/jailbreak.pem"
JAILBREAK_IMAGE="${JAILBREAK_PAYLOAD}/jailbreak.png"
JAILBREAK_IMAGE_PW="${JAILBREAK_PAYLOAD}/jailbreak-pw.png"
JAILBREAK_IMAGE_KV="${JAILBREAK_PAYLOAD}/jailbreak-kv.png"
JAILBREAK_IMAGE_KOA2="${JAILBREAK_PAYLOAD}/jailbreak-koa2.png"
JAILBREAK_DEV_KEYSTORE="${JAILBREAK_PAYLOAD}/jailbreak.keystore"
SCRIPT="/mnt/us/runme.sh"
ROOT=""

# Pull some helper functions for logging
source /etc/upstart/functions

LOG_DOMAIN="jailbreak"

logmsg()
{
	f_log "${1}" "${LOG_DOMAIN}" "${2}" "${3}" "${4}"
}

RW=
mount_rw() {
	if [ -z "$RW" ] ; then
		RW=yes
		mount -o rw,remount /
	fi
}

mount_ro() {
	if [ -n "$RW" ] ; then
		RW=
		mount -o ro,remount /
	fi
}

make_mutable() {
	local my_path="${1}"
	# NOTE: Can't do that on symlinks, hence the hoop-jumping...
	if [ -d "${my_path}" ] ; then
		find "${my_path}" -type d -exec chattr -i '{}' \;
		find "${my_path}" -type f -exec chattr -i '{}' \;
	elif [ -f "${my_path}" ] ; then
		chattr -i "${my_path}"
	fi
}

make_immutable() {
	local my_path="${1}"
	if [ -d "${my_path}" ] ; then
		find "${my_path}" -type d -exec chattr +i '{}' \;
		find "${my_path}" -type f -exec chattr +i '{}' \;
	elif [ -f "${my_path}" ] ; then
		chattr +i "${my_path}"
	fi
}

mount_root_rw()
{
	DEV="$(rdev | awk '{ print $1 }')"
	if [ "${DEV}" != "/dev/mmcblk0p1" ] && [ -n "${DEV}" ] ; then	# K4 doesn't have rdev on rootfs but does on diags, weird
		ROOT="/var/tmp/rootfs"
		logmsg "I" "mount_root_rw" "" "We are not on rootfs, using ${ROOT}"
		[ -d "${ROOT}" ] || mkdir "${ROOT}"
		mount -o rw "/dev/mmcblk0p1" "${ROOT}"
	else
		logmsg "I" "mount_root_rw" "" "We are on rootfs"
		mount_rw
	fi
}

get_version()
{
	awk '/Version:/ { print $NF }' /etc/version.txt | \
		awk -F- '{ print $NF }' | \
		xargs printf "%s\n" | \
		sed -e 's#^0*##'
}

safesource()
{
	[ -f "${1}" ] && . "${1}"
}

install_touch_update_key()
{
	# Only on Kindle 4 & 5
	logmsg "I" "install_touch_update_key" "" "Copying the jailbreak updater key"
	make_mutable "${ROOT}/etc/uks/pubdevkey01.pem"
	cp -af "${JAILBREAK_KEY}" "${ROOT}/etc/uks/pubdevkey01.pem"
	make_immutable "${ROOT}/etc/uks/pubdevkey01.pem"
	return 0
}

install_kindlet_key()
{
	logmsg "I" "install_kindlet_key" "" "Copying the developer keystore"
	mkdir -p "/var/local/java/keystore"
	cp -af "${JAILBREAK_DEV_KEYSTORE}" "/var/local/java/keystore/developer.keystore"
	return 0
}

clean_up_wan()
{
	[ -n "${WAN_INFO}" ] || WAN_INFO="/var/local/wan/info"

	logmsg "I" "clean_up_wan" "" "Cleaning up waninfo file and generating new one"
	rm -f ${WAN_INFO}
	if [ -f "${WAN_INFO}" ] ; then
		logmsg "E" "clean_up_wan" "" "Cannot remove payload. Exiting to prevent boot-loop."
		return 1
	fi

	waninfo
	safesource ${WAN_INFO}
}

clean_up_mntus_params()
{
	[ -n "${MNTUS_PARAMS}" ] || MNTUS_PARAMS="/var/local/system/mntus.params"

	logmsg "I" "clean_up_mntus_params" "" "Cleaning up mntus.params file and generating new one"
	rm -f "${MNTUS_PARAMS}"
	if [ -f "${MNTUS_PARAMS}" ] ; then
		logmsg "E" "clean_up_mntus_params" "" "Cannot remove payload. Exiting to prevent boot-loop."
		return 1
	fi

	if [ -x ${ROOT}/etc/upstart/userstore ] ; then
		# Kindle 5, upstart
		${ROOT}/etc/upstart/userstore start
	fi
	safesource ${MNTUS_PARAMS}
}

clean_up()
{
	logmsg "I" "clean_up" "" "Removing payload files."
	rm -rf "${JAILBREAK_PAYLOAD}"
	clean_up_wan
	clean_up_mntus_params
	if [ -n "${ROOT}" ] ; then
		logmsg "I" "clean_up" "" "Unmounting rootfs"
		umount "${ROOT}"
	fi
}

# Step 0, log who triggered us
logmsg "I" "jailbreak" "" "Running from: ${0}"

# Step 1, we clear the screen
eips -c

# Step 2, check device version
VERSION=0
kpver="$(grep '^Kindle [12345]' /etc/prettyversion.txt 2>&1)"
if [ $? -ne 0 ] ; then
	logmsg "W" "jailbreak" "" "Couldn't detect the Kindle version!"
	VERSION=0
else
	# Weeee, the great case switch!
	khver="$(echo ${kpver} | sed -n -r 's/^(Kindle)([[:blank:]]*)([[:digit:].]*)(.*?)$/\3/p')"
	case "${khver}" in
		1* )
			VERSION=1
		;;
		2* )
			VERSION=2
		;;
		3* )
			VERSION=3
		;;
		4* )
			VERSION=4
		;;
		5* )
			VERSION=5
		;;
		* )
			VERSION=0
		;;
	esac
fi
logmsg "I" "jailbreak" "" "Kindle version: ${VERSION}"
# Some diags version don't have a properly formatted prettyversion, fallback to model based detection...
kmodel="$(cut -c3-4 /proc/usid)"	# NOTE: If this isn't enough, we could also use $(idme --serial ?), but I'd vastly prefer to keep using a ro 'inert' file...
if [ $? -ne 0 ] ; then
	logmsg "W" "jailbreak" "" "Couldn't detect the Kindle model!"
	VERSION=0
else
	logmsg "I" "jailbreak" "" "Kindle model: ${kmodel}"
	if [ "${VERSION}" -le "0" ] ; then
		case "${kmodel}" in
			"01" )
				VERSION=1
			;;
			"02" | "03" | "04" | "05" | "09" )
				VERSION=2
			;;
			"08" | "06" | "0A" )
				VERSION=3
			;;
			"0E" | "23" )
				VERSION=4
			;;
			"0F" | "11" | "10" | "12" | "24" | "1B" | "1D" | "1F" | "1C" | "20" | "D4" | "5A" | "D5" | "D6" | "D7" | "D8" | "F2" | "17" | "60" | "F4" | "F9" | "62" | "61" | "5F" | "C6" | "DD" | "13" | "54" | "2A" | "4F" | "52" | "53" )
				VERSION=5
			;;
			* )
				# Try the new device ID scheme...
				kmodel="$(cut -c4-6 /proc/usid)"
				logmsg "I" "jailbreak" "" "Kindle model (new device ID scheme): ${kmodel}"
				case "${kmodel}" in
					"0G1" | "0G2" | "0G4" | "0G5" | "0G6" | "0G7" | "0KB" | "0KC" | "0KD" | "0KE" | "0KF" | "0KG" | "0LK" | "0LL" | "0GC" | "0GD" | "0GR" | "0GS" | "0GT" | "0GU" | "0DU" | "0K9" | "0KA" | "0LM" | "0LN" | "0LP" | "0LQ" | "0P1" | "0P2" | "0P6" | "0P7" | "0P8" | "0S1" | "0S2" | "0S3" | "0S4" | "0S7" | "0SA" | "0PP" | "0T1" | "0T2" | "0T3" | "0T4" | "0T5" | "0T6" | "0T7" | "0TJ" | "0TK" | "0TL" | "0TM" | "0TN" | "102" | "103" | "16Q" | "16R" | "16S" | "16T" | "16U" | "16V" | "10L" | "0WF" | "0WG" | "0WH" | "0WJ" | "0VB" | "11L" | "0WQ" | "0WP" | "0WN" | "0WM" | "0WL" )
						VERSION=5
					;;
					* )
						VERSION=0
					;;
				esac
			;;
		esac
		logmsg "I" "jailbreak" "" "Kindle version (from model): ${VERSION}"
	fi
fi
# And the last-chance fallback, revision based detection...
REVISION="$(get_version)"
logmsg "I" "jailbreak" "" "Kindle revision: ${REVISION}"
# FIXME: As time passes, this becomes more and more inaccurate, which is why it's only used as a last resort fallback...
if [ "${VERSION}" -le "0" ] ; then
	if [ "${REVISION}" -lt "29133" ] ; then
		VERSION=1
	elif [ "${REVISION}" -lt "51546" ] ; then
		VERSION=2
	elif [ "${REVISION}" -lt "130856" ] ; then	# FIXME: Kindle 3.4 is > main 5.1.0...
		VERSION=3
	elif [ "${REVISION}" -lt "137022" ] ; then	# FIXME: Kindle main 4.1.0 is > main 5.1.0...
		VERSION=4
	else
		VERSION=5
	fi
	logmsg "I" "jailbreak" "" "Kindle version (from revision, inaccurate): ${VERSION}"
fi
# Recap what we've detected...
logmsg "I" "jailbreak" "" "Assume Kindle version: ${VERSION}"

# Step 3, we put a pretty image on screen, in the proper resolution depending on the device
case "${kmodel}" in
	"13" | "54" | "2A" | "4F" | "52" | "53" )
		# 1072x1448 on the KV
		eips -f -g "${JAILBREAK_IMAGE_KV}"
	;;
	"24" | "1B" | "1D" | "1F" | "1C" | "20" | "D4" | "5A" | "D5" | "D6" | "D7" | "D8" | "F2" | "17" | "60" | "F4" | "F9" | "62" | "61" | "5F" )
		# 758x1024 on the PW
		eips -f -g "${JAILBREAK_IMAGE_PW}"
	;;
	"0F" | "11" | "10" | "12" | "C6" | "DD" )
		# 600x800 on the Touch & KT2
		eips -f -g "${JAILBREAK_IMAGE}"
	;;
	# Try the new device ID scheme... kmodel will always point to our actual device code, no matter the scheme.
	"0G1" | "0G2" | "0G4" | "0G5" | "0G6" | "0G7" | "0KB" | "0KC" | "0KD" | "0KE" | "0KF" | "0KG" | "0LK" | "0LL" | "0GC" | "0GD" | "0GR" | "0GS" | "0GT" | "0GU" | "0PP" | "0T1" | "0T2" | "0T3" | "0T4" | "0T5" | "0T6" | "0T7" | "0TJ" | "0TK" | "0TL" | "0TM" | "0TN" | "102" | "103" | "16Q" | "16R" | "16S" | "16T" | "16U" | "16V" )
		# 1072x1448 on the PW3/PW4 & Oasis (as on the KV)
		eips -f -g "${JAILBREAK_IMAGE_KV}"
	;;
	"0DU" | "0K9" | "0KA" | "10L" | "0WF" | "0WG" | "0WH" | "0WJ" | "0VB" )
		# 600x800 on the KT3/KT4
		eips -f -g "${JAILBREAK_IMAGE}"
	;;
	"0LM" | "0LN" | "0LP" | "0LQ" | "0P1" | "0P2" | "0P6" | "0P7" | "0P8" | "0S1" | "0S2" | "0S3" | "0S4" | "0S7" | "0SA" | "11L" | "0WQ" | "0WP" | "0WN" | "0WM" | "0WL" )
		# 1264x1680 on the Oasis 2/3
		eips -f -g "${JAILBREAK_IMAGE_KOA2}"
	;;
	* )
		# 600x800 as a fallback
		eips -f -g "${JAILBREAK_IMAGE}"
	;;
esac

# Step 4, go away if we're not on a Kindle 5 (We shouldn't ever hit this, but let's be on the safe side)
if [ "${VERSION}" -lt "5" ] ; then
	logmsg "E" "jailbreak" "" "We're not on a Kindle 5, go away!"
	# Cleanup before exiting!
	sleep 5
	clean_up
	exit 0
fi

# Step 5, install updater key
mount_root_rw
if [ "${VERSION}" -ge "5" ] ; then
	install_touch_update_key
fi
mount_ro

# Step 6, install kindlet key
install_kindlet_key

# Step 7, wait a bit while our cool splash screen is up and then clean up
sleep 10
clean_up

# Step 8, run any custom scripts (must do this after cleanup so we have the userstore mounted)
if [ -f "${SCRIPT}" ] ; then
	logmsg "I" "jailbreak" "" "Found script ${SCRIPT}, running it"
	[ -x "${SCRIPT}" ] || chmod +x "${SCRIPT}"
	${SCRIPT}
fi

# Step 9, leave a trace so the user knows they are jailbroken
echo "It is safe to delete this document." > "/mnt/us/documents/You are Jailbroken.txt"

exit 0	# required in case we have trailing junk data from a payload
