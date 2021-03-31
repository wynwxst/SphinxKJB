#!/bin/sh
#
# Kindle Touch Ninja JB
# Heavily based on stuff created by Yifan Lu <http://yifan.lu/>
#
# $Id: install-ninja.sh 15003 2018-06-01 23:09:01Z NiLuJe $
#
##

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

mount_root_rw()
{
	DEV="$(rdev | awk '{ print $1 }')"
	if [ "${DEV}" != "/dev/mmcblk0p1" -a -n "${DEV}" ] ; then	# K4 doesn't have rdev on rootfs but does on diags, weird
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
	clean_up_wan
	clean_up_mntus_params
	if [ -n "${ROOT}" ] ; then
		logmsg "I" "clean_up" "" "Unmounting rootfs"
		umount "${ROOT}"
	fi
}

# Step 0, log who triggered us
logmsg "I" "jailbreak" "" "Running from: ${0}"

# Step 1, we say hello
eips 0 $((800 / 20 - 2)) "                **** JAILBREAK ****               "

# Step 2, clean up
clean_up

# Step 3, run any custom scripts (must do this after cleanup so we have the userstore mounted)
if [ -f "${SCRIPT}" ] ; then
	logmsg "I" "jailbreak" "" "Found script ${SCRIPT}, running it"
	[ -x "${SCRIPT}" ] || chmod +x "${SCRIPT}"
	${SCRIPT}
fi

exit 0	# required in case we have trailing junk data from a payload
