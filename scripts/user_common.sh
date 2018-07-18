# user_common.sh : common code for user administration scripts
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
# Author: Vincent Strubel <clipos@ssi.gouv.fr>
# Most code is EADS DCS
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#

AWK="/bin/awk"
CAT="/bin/cat"
CHMOD="/bin/chmod"
CHOWN="/bin/chown"
CP="/bin/cp"
CRACK_CHECK="/usr/sbin/cracklib-check"
CRYPTPASSWORD="/usr/bin/cryptpasswd"
CRYPTSETUP="/bin/cryptsetup"
CUT="/usr/bin/cut"
DD="/bin/dd"
DIALOG="/usr/local/bin/xdialog.sh"
GREP="/bin/grep"
GRPS="/bin/groups"
HEAD="/usr/bin/head"
ID="/usr/bin/id"
LAST="/usr/bin/last"
LN="/bin/ln"
LOGGER="/usr/bin/logger"
LOSETUP="/sbin/losetup"
LS="/bin/ls"
MKDIR="/bin/mkdir"
MKE2FS="/sbin/mke2fs"
MOUNT="/bin/mount"
MV="/bin/mv"
OPENSSL="/usr/bin/openssl"
RM="/bin/rm"
RMDIR="/bin/rmdir"
SSH_KEYGEN="/usr/local/bin/ssh-keygen"
TR="/usr/bin/tr"
UMOUNT="/bin/umount"
USERADD="/usr/sbin/useradd"
USERDEL="/usr/sbin/userdel"
USERMOD="/usr/sbin/usermod"
USER_ENTER="/sbin/vsctl user enter"
WC="/bin/wc"
XDIALOG="/usr/local/bin/Xdialog"

LC="fr_FR"

function error()
{
    ${LOGGER} -i -s -p daemon.err -t "${SCRIPT_NAME}" -- "${1}"
    [ "x"${CURRENT_USER} = "x" ] && exit -1
    
    if [[ -z "${AUTHORITY}" ]]; then 
	get_user_connected
        if [[ -z "${AUTHORITY}" ]]; then
        	${LOGGER} -i -s -p daemon.err -t "${SCRIPT_NAME}" -- "Could not get Xauthority"
                exit -1
	fi
    fi
    
    XDIALOG_MESSAGE="Erreur : ${1}"
    XDIALOG_TITLE="${XDIALOG_ERROR_TITLE}"
   
    ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --msgbox "${XDIALOG_MESSAGE}" 6 80

    exit -1
}

function debug()
{
    ${LOGGER} -i -s -p daemon.info -t "${SCRIPT_NAME}" -- "${1}"
}

function delete_file()
{
    [ -f "${1}" ] && ${RM} -f "${1}"
}

function get_user_connected()
{
    if [[ -f "/user/home/user/.Xauthority" ]]; then
    	AUTHORITY="/home/user/.Xauthority"	# SLIM
    else 
    	AUTHORITY="$(${LS} -1t /user/tmp/.Xauth* 2>/dev/null | ${HEAD} -1)" # XDM
    	AUTHORITY="${AUTHORITY#/user}"
    fi
    [[ -n "${AUTHORITY}" ]] || error "Impossible de determiner XAUTHORITY"

    CURRENT_USER="$(${LAST} -w -f /var/run/utmp | ${AWK} '$2 ~ /^:0/ { print $1 }' | ${HEAD} -n 1)"
    [[ -n "${CURRENT_USER}" ]] || error "Impossible de recuperer l'utilisateur connecte"
    
    CURRENT_UID=$(${ID} -u ${CURRENT_USER})
    [[ -n "${CURRENT_UID}" ]] || error "Impossible de recuperer l'uid de l'utilisateur"
}

function passwd_check()
{
	local pass="${1}"
	local check

	check="$(echo "${pass}" | LC_ALL=${LC} ${CRACK_CHECK})"
	echo "${check}" | ${GREP} -q ': OK' && return 0

	# Error message
	echo "${check##*: }"
	return 1
}

function passwd_check_loop()
{
	local pass="${1}"
	local msg=""
	local xdialog_title="Nouvelle saisie du mot de passe"

	while /bin/true; do
		msg="$(passwd_check "${pass}")"
		if [[ -z "${msg}" ]]; then
			echo "${pass}"
			return 0
		fi

		local xdialog_msg="Mot de passe ${msg}. Veuillez en saisir un autre."
		pass="$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${xdialog_title}" --inputbox "${xdialog_msg}" 10 90 2>&1)"
		[[ $? -ne 0 ]] && error "Erreur dans la saisie du mot de passe"
	done
}

		
