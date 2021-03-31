#!/bin/sh
#
# Quick'n dirty JB+Bridge recovery script for use via RUNME or emergency
# c.f., https://www.mobileread.com/forums/showthread.php?p=3961863#post3961863
#
# $Id: install-emergency.sh 18326 2021-03-24 18:06:42Z NiLuJe $
#
##

# Helper functions, in case the bridge was still kicking.
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
# We actually do need that one
make_immutable() {
	local my_path="${1}"
	if [ -d "${my_path}" ] ; then
		find "${my_path}" -type d -exec chattr +i '{}' \;
		find "${my_path}" -type f -exec chattr +i '{}' \;
	elif [ -f "${my_path}" ] ; then
		chattr +i "${my_path}"
	fi
}

[ -f "/etc/upstart/functions" ] && source /etc/upstart/functions
f_log I emergency main "" "ohai!"

# Whee!
mntroot rw

# JB first
make_mutable "/etc/uks/pubdevkey01.pem"
rm -rf "/etc/uks/pubdevkey01.pem"
cat > "/etc/uks/pubdevkey01.pem" << EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDJn1jWU+xxVv/eRKfCPR9e47lP
WN2rH33z9QbfnqmCxBRLP6mMjGy6APyycQXg3nPi5fcb75alZo+Oh012HpMe9Lnp
eEgloIdm1E4LOsyrz4kttQtGRlzCErmBGt6+cAVEV86y2phOJ3mLk0Ek9UQXbIUf
rvyJnS2MKLG2cczjlQIDAQAB
-----END PUBLIC KEY-----
EOF
RET="$?"
f_log I emergency jb "" "installed jb (${RET})"
chown root:root "/etc/uks/pubdevkey01.pem"
chmod 0644 "/etc/uks/pubdevkey01.pem"
make_immutable "/etc/uks/pubdevkey01.pem"

# Then bridge
mkdir -p "/var/local/system"
cp -f "/mnt/us/bridge.sh" "/var/local/system/fixup"
RET="$?"
f_log I emergency bridge "" "installed bridge (${RET})"
chown root:root "/var/local/system/fixup"
chmod a+rx "/var/local/system/fixup"

# Then bridget
make_mutable "/etc/upstart/bridge.conf"
cp -f "/mnt/us/bridge.conf" "/etc/upstart/bridge.conf"
RET="$?"
f_log I emergency bridget "" "installed bridget (${RET})"
chown root:root "/etc/upstart/bridge.conf"
chmod 0664 "/etc/upstart/bridge.conf"
make_immutable "/etc/upstart/bridge.conf"

# Bye
sync
mntroot ro

# Bye now!
f_log I emergency main "" "cleanup"
rm -f "/mnt/us/RUNME.sh"
rm -f "/mnt/us/emergency.sh"
rm -f "/mnt/us/bridge.sh"
rm -f "/mnt/us/bridge.conf"

f_log I emergency main "" "bye now!"
