#!/bin/sh
#
# Kindle Touch/PaperWhite JailBreak Install
#
# $Id: 5.4-install.sh 17396 2020-05-24 03:16:18Z NiLuJe $
#
##


# Pull some helper functions for logging
source /etc/upstart/functions

ROOT=""
VARLOCAL_OOS="false"

LOG_DOMAIN="jb_install"

logmsg()
{
	f_log "${1}" "${LOG_DOMAIN}" "${2}" "${3}" "${4}"
}

RW=""
mount_rw() {
	if [ -z "${RW}" ] ; then
		RW="yes"
		mount -o rw,remount /
	fi
}

mount_ro() {
	if [ -n "${RW}" ] ; then
		RW=""
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
	# Check if we're running from main...
	DEV="$(rdev | awk '{ print $1 }')"
	# Don't do something stupid if rdev is missing for some reason...
	if [ "${DEV}" != "/dev/mmcblk0p1" ] && [ -n "${DEV}" ] ; then
		ROOT="/var/tmp/rootfs"
		logmsg "I" "mount_root_rw" "" "Running from diags, mounting main rootfs on ${ROOT}"
		mkdir -p "${ROOT}"
		mount -o rw "/dev/mmcblk0p1" "${ROOT}"
	else
		logmsg "I" "mount_root_rw" "" "Mounting rootfs rw"
		mount_rw
	fi
}

IS_TOUCH="false"
IS_PW="false"
IS_PW2="false"
IS_KV="false"
IS_KT2="false"
IS_PW3="false"
IS_KOA="false"
IS_KT3="false"
IS_KOA2="false"
IS_PW4="false"
IS_KT4="false"
IS_KOA3="false"
K5_ATLEAST_54="false"
check_model()
{
	# Do the S/N dance...
	kmodel="$(cut -c3-4 /proc/usid)"
	case "${kmodel}" in
		"24" | "1B" | "1D" | "1F" | "1C" | "20" )
			# PaperWhite 1 (2012)
			IS_PW="true"
		;;
		"D4" | "5A" | "D5" | "D6" | "D7" | "D8" | "F2" | "17" | "60" | "F4" | "F9" | "62" | "61" | "5F" )
			# PaperWhite 2 (2013)
			IS_PW="true"
			IS_PW2="true"
		;;
		"13" | "54" | "2A" | "4F" | "52" | "53" )
			# Voyage...
			IS_KV="true"
		;;
		"C6" | "DD" )
			# KT2...
			IS_TOUCH="true"
			IS_KT2="true"
		;;
		"0F" | "11" | "10" | "12" )
			# Touch
			IS_TOUCH="true"
		;;
		* )
			# Try the new device ID scheme...
			kmodel="$(cut -c4-6 /proc/usid)"
			case "${kmodel}" in
				"0G1" | "0G2" | "0G4" | "0G5" | "0G6" | "0G7" | "0KB" | "0KC" | "0KD" | "0KE" | "0KF" | "0KG" | "0LK" | "0LL" )
					# PW3...
					IS_PW3="true"
				;;
				"0GC" | "0GD" | "0GR" | "0GS" | "0GT" | "0GU" )
					# Oasis...
					IS_KOA="true"
				;;
				"0DU" | "0K9" | "0KA" )
					# KT3...
					IS_KT3="true"
				;;
				"0LM" | "0LN" | "0LP" | "0LQ" | "0P1" | "0P2" | "0P6" | "0P7" | "0P8" | "0S1" | "0S2" | "0S3" | "0S4" | "0S7" | "0SA" )
					# KOA2...
					IS_KOA2="true"
				;;
				"0PP" | "0T1" | "0T2" | "0T3" | "0T4" | "0T5" | "0T6" | "0T7" | "0TJ" | "0TK" | "0TL" | "0TM" | "0TN" | "102" | "103" | "16Q" | "16R" | "16S" | "16T" | "16U" | "16V" )
					# PW4...
					IS_PW4="true"
				;;
				"10L" | "0WF" | "0WG" | "0WH" | "0WJ" | "0VB" )
					# KT4...
					IS_KT4="true"
				;;
				"11L" | "0WQ" | "0WP" | "0WN" | "0WM" | "0WL" )
					# KOA3...
					IS_KOA3="true"
				;;
				* )
					# Fallback... We shouldn't ever hit that.
					IS_TOUCH="true"
				;;
			esac
		;;
	esac

	# Use the proper constants for our screen...
	if [ "${IS_KV}" == "true" ] || [ "${IS_PW3}" == "true" ] || [ "${IS_KOA}" == "true" ] || [ "${IS_PW4}" == "true" ] ; then
		SCREEN_X_RES=1088
		SCREEN_Y_RES=1448
		EIPS_X_RES=16
		EIPS_Y_RES=24
	elif [ "${IS_PW}" == "true" ] ; then
		SCREEN_X_RES=768
		SCREEN_Y_RES=1024
		EIPS_X_RES=16
		EIPS_Y_RES=24
	elif [ "${IS_KT2}" == "true" ] || [ "${IS_KT3}" == "true" ] || [ "${IS_KT4}" == "true" ] ; then
		SCREEN_X_RES=608
		SCREEN_Y_RES=800
		EIPS_X_RES=16
		EIPS_Y_RES=24
	elif [ "${IS_KOA2}" == "true" ] || [ "${IS_KOA3}" == "true" ] ; then
		SCREEN_X_RES=1280
		SCREEN_Y_RES=1680
		EIPS_X_RES=16
		EIPS_Y_RES=24
	else
		SCREEN_X_RES=600
		SCREEN_Y_RES=800
		EIPS_X_RES=12
		EIPS_Y_RES=20
	fi
	EIPS_MAXCHARS="$((${SCREEN_X_RES} / ${EIPS_X_RES}))"
	EIPS_MAXLINES="$((${SCREEN_Y_RES} / ${EIPS_Y_RES}))"
}

check_version()
{
	# The great version check!
	kpver="$(grep '^Kindle 5' /etc/prettyversion.txt 2>&1)"
	if [ $? -ne 0 ] ; then
		logmsg "W" "check_version" "" "couldn't detect the kindle major version!"
		# We're in a bit of a pickle... Make an educated guess...
		if [ "${IS_PW2}" == "true" ] ; then
			# The PW2 shipped on 5.4.0 ;)
			logmsg "I" "check_version" "" "PW2 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KV}" == "true" ] ; then
			# The KV shipped on 5.5.0 ;)
			logmsg "I" "check_version" "" "KV detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KT2}" == "true" ] ; then
			# The KT2 shipped on 5.6.0 ;)
			logmsg "I" "check_version" "" "KT2 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_PW3}" == "true" ] ; then
			# The PW3 shipped on 5.6.1 ;)
			logmsg "I" "check_version" "" "PW3 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KOA}" == "true" ] ; then
			# The Oasis shipped on 5.7.1.1 ;)
			logmsg "I" "check_version" "" "Oasis detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KT3}" == "true" ] ; then
			# The KT3 shipped on >= 5.7.x ;)
			logmsg "I" "check_version" "" "KT3 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KOA2}" == "true" ] ; then
			# The KOA2 shipped on >= 5.9.0.x ;)
			logmsg "I" "check_version" "" "KOA2 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_PW4}" == "true" ] ; then
			# The PW4 shipped on >= 5.10.0.x ;)
			logmsg "I" "check_version" "" "PW4 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KT4}" == "true" ] ; then
			# The KT4 shipped on >= 5.1x.y ;)
			logmsg "I" "check_version" "" "KT4 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		elif [ "${IS_KOA3}" == "true" ] ; then
			# The KOA2 shipped on >= 5.12.x ;)
			logmsg "I" "check_version" "" "KOA3 detected, assuming >= 5.4"
			K5_ATLEAST_54="true"
		else
			# Poor man's last resort trick. See if we can find a new feature of FW 5.4 on the FS...
			if [ -f "${ROOT}/etc/upstart/contentpackd.conf" ] ; then
				logmsg "I" "check_version" "" "found a fw >= 5.4 feature"
				K5_ATLEAST_54="true"
			fi
		fi
	else
		# Weeee, the great case switch!
		khver="$(echo ${kpver} | sed -n -r 's/^(Kindle)([[:blank:]]*)([[:digit:].]*)(.*?)$/\3/p')"
		case "${khver}" in
			5.0.* | 5.0 )
				K5_ATLEAST_54="false"
			;;
			5.1.* | 5.1 )
				K5_ATLEAST_54="false"
			;;
			5.2.* | 5.2 )
				K5_ATLEAST_54="false"
			;;
			5.3.* | 5.3 )
				K5_ATLEAST_54="false"
			;;
			5.4.* | 5.4 )
				K5_ATLEAST_54="true"
			;;
			5.5.* | 5.5 )
				K5_ATLEAST_54="true"
			;;
			5.6.* | 5.6 )
				K5_ATLEAST_54="true"
			;;
			5.7.* | 5.7 )
				K5_ATLEAST_54="true"
			;;
			5.8.* | 5.8 )
				K5_ATLEAST_54="true"
			;;
			5.9.* | 5.9 )
				K5_ATLEAST_54="true"
			;;
			5.10.* | 5.10 )
				K5_ATLEAST_54="true"
			;;
			5.11.* | 5.11 )
				K5_ATLEAST_54="true"
			;;
			5.12.* | 5.12 )
				K5_ATLEAST_54="true"
			;;
			5.* )
				# Assume newer, just to be safe ;)
				K5_ATLEAST_54="true"
			;;
			* )
				# Given the previous checks, this shouldn't be reachable, but cover all bases anyway...
				logmsg "W" "check_version" "" "couldn't detect the kindle version!"
				# Poor man's last resort trick. See if we can find a new feature of FW 5.4 on the FS...
				if [ -f "${ROOT}/etc/upstart/contentpackd.conf" ] ; then
					logmsg "I" "check_version" "" "found a fw >= 5.4 feature"
					K5_ATLEAST_54="true"
				fi
			;;
		esac
	fi
}

print_jb_install_feedback()
{
	# Prepare our stuff... Print an extra warning if we failed to setup the bridge and/or MKK...
	if [ "${VARLOCAL_OOS}" == "true" ] ; then
		kh_eips_string="**** JB - WARNING: BRIDGE SETUP FAILED ****"
	else
		kh_eips_string="**** JAILBREAK ****"
	fi

	# And finally, show our message, centered on the bottom of the screen
	eips $(((${EIPS_MAXCHARS} - ${#kh_eips_string}) / 2)) $((${EIPS_MAXLINES} - 2)) "${kh_eips_string}"
}

install_update_key()
{
	logmsg "I" "install_update_key" "" "Copying the jailbreak updater key"
	make_mutable "${ROOT}/etc/uks/pubdevkey01.pem"
	cat > "${ROOT}/etc/uks/pubdevkey01.pem" << EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDJn1jWU+xxVv/eRKfCPR9e47lP
WN2rH33z9QbfnqmCxBRLP6mMjGy6APyycQXg3nPi5fcb75alZo+Oh012HpMe9Lnp
eEgloIdm1E4LOsyrz4kttQtGRlzCErmBGt6+cAVEV86y2phOJ3mLk0Ek9UQXbIUf
rvyJnS2MKLG2cczjlQIDAQAB
-----END PUBLIC KEY-----
EOF
	make_immutable "${ROOT}/etc/uks/pubdevkey01.pem"
}

install_fw54_exec_userstore_flag()
{
	# FW >= 5.4 only...
	if [ "${K5_ATLEAST_54}" == "true" ] ; then
		logmsg "I" "install_fw54_exec_userstore_flag" "" "Creating the userstore exec flag file"
		make_mutable "${ROOT}/MNTUS_EXEC"
		touch "${ROOT}/MNTUS_EXEC"
		make_immutable "${ROOT}/MNTUS_EXEC"
	fi
}

check_assets()
{
	# Make sure we have everything we need before trying to copy custom stuff...
	for my_asset in bridge.sh bridge.conf developer.keystore json_simple-1.1.jar gandalf ; do
		if [ ! -f "/mnt/us/${my_asset}" ] ; then
			logmsg "E" "check_assets" "" "${my_asset} is missing from the userstore, aborting"
			# This is fatal, cleanup and go away...
			# NOTE: By this point, we should at least have installed our public key though, so all is not lost ;).
			mount_ro
			clean_up
			# Fake an error to print a meaningful warning before exiting...
			VARLOCAL_OOS="true"
			print_jb_install_feedback
			exit 1
		fi
	done
}

install_bridge()
{
	logmsg "I" "install_bridge" "" "Installing the jailbreak bridge"
	if [ "$(df -k /var/local | awk '$3 ~ /[0-9]+/ { print $4 }')" -lt "512" ] ; then
		# Hu ho... Keep track of this...
		VARLOCAL_OOS="true"
		logmsg "W" "install" "" "Failed to setup the jailbreak bridge: not enough space left on device"
	else
		cp -f "/mnt/us/bridge.sh" "/var/local/system/fixup"
		chown root:root "/var/local/system/fixup"
		chmod a+rx "/var/local/system/fixup"
	fi

	# And the bridge job...
	make_mutable "${ROOT}/etc/upstart/bridge.conf"
	cp -f "/mnt/us/bridge.conf" "${ROOT}/etc/upstart/bridge.conf"
	chmod 0664 "${ROOT}/etc/upstart/bridge.conf"
	make_immutable "${ROOT}/etc/upstart/bridge.conf"
}

install_persistent_mkk()
{
	MKK_PERSISTENT_STORAGE="/var/local/mkk"
	MKK_BACKUP_STORAGE="/mnt/us/mkk"
	logmsg "I" "install" "" "Setting up MKK persistent copy"
	if [ "$(df -k /var/local | awk '$3 ~ /[0-9]+/ { print $4 }')" -lt "512" ] ; then
		# Hu ho... Keep track of this...
		VARLOCAL_OOS="true"
		logmsg "W" "install" "" "Failed to setup MKK persistent copy: not enough space left on device"
	else
		make_mutable "${MKK_PERSISTENT_STORAGE}"
		rm -rf "${MKK_PERSISTENT_STORAGE}"
		mkdir -p "${MKK_PERSISTENT_STORAGE}"
		chown root:root "${MKK_PERSISTENT_STORAGE}"
		chmod g-s "${MKK_PERSISTENT_STORAGE}"
		cp -f "/mnt/us/developer.keystore" "${MKK_PERSISTENT_STORAGE}/developer.keystore"
		cp -f "/mnt/us/json_simple-1.1.jar" "${MKK_PERSISTENT_STORAGE}/json_simple-1.1.jar"
		cp -f "/mnt/us/gandalf" "${MKK_PERSISTENT_STORAGE}/gandalf"
		cp -f "/mnt/us/bridge.sh" "${MKK_PERSISTENT_STORAGE}/bridge.sh"
		cp -f "/mnt/us/bridge.conf" "${MKK_PERSISTENT_STORAGE}/bridge.conf"

		chown root:root "${MKK_PERSISTENT_STORAGE}/gandalf"
		chmod a+rx "${MKK_PERSISTENT_STORAGE}/gandalf"
		chmod +s "${MKK_PERSISTENT_STORAGE}/gandalf"
		ln -sf "${MKK_PERSISTENT_STORAGE}/gandalf" "${MKK_PERSISTENT_STORAGE}/su"
		make_immutable "${MKK_PERSISTENT_STORAGE}"

		rm -rf "${MKK_BACKUP_STORAGE}"
		mkdir -p "${MKK_BACKUP_STORAGE}"
		for my_file in "${MKK_PERSISTENT_STORAGE}"/* ; do
			if [ -f "${my_file}" ] && [ ! -L "${my_file}" ] ; then
				cp -f "${my_file}" "${MKK_BACKUP_STORAGE}/"
			fi
		done
	fi
}

install_persistent_rp()
{
	RP_PERSISTENT_STORAGE="/var/local/rp"
	RP_BACKUP_STORAGE="/mnt/us/rp"
	logmsg "I" "install" "" "Setting up RP persistent copy"
	if [ "$(df -k /var/local | awk '$3 ~ /[0-9]+/ { print $4 }')" -lt "512" ] ; then
		# Hu ho... Keep track of this...
		VARLOCAL_OOS="true"
		logmsg "W" "install" "" "Failed to setup RP persistent copy: not enough space left on device"
	else
		make_mutable "${RP_PERSISTENT_STORAGE}"
		rm -rf "${RP_PERSISTENT_STORAGE}"
		mkdir -p "${RP_PERSISTENT_STORAGE}"
		chown root:root "${RP_PERSISTENT_STORAGE}"
		chmod g-s "${RP_PERSISTENT_STORAGE}"
		for my_job in debrick cowardsdebrick ; do
			if [ -f "${ROOT}/etc/upstart/${my_job}.conf" ] ; then
				cp -af "${ROOT}/etc/upstart/${my_job}.conf" "${RP_PERSISTENT_STORAGE}/${my_job}.conf"
			fi
			if [ -f "${ROOT}/etc/upstart/${my_job}" ] ; then
				cp -af "${ROOT}/etc/upstart/${my_job}" "${RP_PERSISTENT_STORAGE}/${my_job}"
			fi
		done
		make_immutable "${RP_PERSISTENT_STORAGE}"

		rm -rf "${RP_BACKUP_STORAGE}"
		mkdir -p "${RP_BACKUP_STORAGE}"
		for my_file in "${RP_PERSISTENT_STORAGE}"/* ; do
			if [ -f "${my_file}" ] && [ ! -L "${my_file}" ] ; then
				cp -f "${my_file}" "${RP_BACKUP_STORAGE}/"
			fi
		done
	fi
}

clean_up()
{
	# Cleanup behind us...
	rm -f "/mnt/us/bridge.sh" "/mnt/us/developer.keystore" "/mnt/us/json_simple-1.1.jar" "/mnt/us/gandalf" "/mnt/us/bridge.conf" /mnt/us/*.bin "/mnt/us/jailbreak.sh"
	# Unmount main rootfs if we're on diags...
	if [ -n "${ROOT}" ] ; then
		logmsg "I" "clean_up" "" "Unmounting main rootfs"
		umount "${ROOT}"
	fi
}


## And... Go!
check_model
check_version
mount_root_rw
install_update_key
install_fw54_exec_userstore_flag
check_assets
install_bridge
install_persistent_mkk
install_persistent_rp
mount_ro
print_jb_install_feedback
clean_up

return 0
