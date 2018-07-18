#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

###################################################################################
#
# EADS DCS
#
# Modify user
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#
####################################################################################

# Modified to encrypt partition keys with a bcrypt hash of the password.
# 2008/03/17 - Vincent Strubel <clipos@ssi.gouv.fr>
# Modified to use common functions from user_common.sh
# 2008/03/27 - Vincent Strubel <clipos@ssi.gouv.fr>

source /lib/clip/userkeys.sub || exit 1

SCRIPT_NAME="MODIFY_USER"
XDIALOG_ERROR_TITLE="Modification de l'utilisateur"

source /sbin/user_common.sh || exit 1

####################################
############ Util code #############
####################################

function get_old_password()
{
    XDIALOG_MESSAGE="Veuillez saisir l'ancien mot de passe :"
    XDIALOG_TITLE="Modification de l'utilisateur ${CURRENT_USER}"

    OLD_PASSPHRASE=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${XDIALOG_TITLE}" --inputbox "${XDIALOG_MESSAGE}" 10 60 2>&1)
    [ $? -ne 0 ] && error "Erreur dans la saisie de l'ancien mot de passe"
}

function get_new_password()
{
    XDIALOG_MESSAGE="Veuillez saisir le nouveau mot de passe :"
    XDIALOG_TITLE="Modification de l'utilisateur ${CURRENT_USER}"
    local pass

    pass=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${XDIALOG_TITLE}" --inputbox "${XDIALOG_MESSAGE}" 10 60 2>&1)
    [[ $? -ne 0 ]] && error "Erreur dans la saisie du nouveau mot de passe"
    NEW_PASSPHRASE="$(passwd_check_loop "${pass}")"
    [[ -z "${NEW_PASSPHRASE}" ]] && error "Abandon de la saisie"
    
    XDIALOG_MESSAGE="Veuillez re-saisir le nouveau mot de passe :"
    XDIALOG_TITLE="Modification de l'utilisateur ${CURRENT_USER}"

    NEW_PASSPHRASE_BIS=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${XDIALOG_TITLE}" --inputbox "${XDIALOG_MESSAGE}" 10 60 2>&1)
    [ $? -ne 0 ] && error "Erreur dans la re-saisie du nouveau mot de passe"

    [ "${NEW_PASSPHRASE}" != "${NEW_PASSPHRASE_BIS}" ] && error "Les deux mots de passe saisis sont différents"
}

function encrypt_password()
{
    ENCRYPTED_PASSWORD="$(PASS="${NEW_PASSPHRASE}" hash_password "PASS")"
    [ $? -ne 0 ] && error "Erreur dans le chiffrement du mot de passe"
}

function modify_home()
{
    local KEY_FILE="$1/keys/${CURRENT_USER}.key"
    local NEW_KEY_FILE="$1/keys/${CURRENT_USER}.key.new"
    local SETTINGS_FILE="$1/keys/${CURRENT_USER}.settings"
    local NEW_SETTINGS_FILE="$1/keys/${CURRENT_USER}.settings.new"
    local key

    create_settings "${CURRENT_USER}" "${NEW_SETTINGS_FILE}" || \
    	error "Erreur dans la création du salt"

    key="$(PASS="${OLD_PASSPHRASE}" output_stage2_key \
    		"${SETTINGS_FILE}" "PASS" "${KEY_FILE}")"

    [[ $? -ne 0 ]] && error "Erreur dans le déchiffrement de la clé"

    echo -n "${key}" | \
        PASS=${NEW_PASSPHRASE} encrypt_stage2_key "${NEW_SETTINGS_FILE}" \
		"PASS" "${NEW_KEY_FILE}" \
		|| error_rollback "Erreur dans le chiffrement de la clé"

    ${MV} $NEW_KEY_FILE $KEY_FILE
    ${MV} $NEW_SETTINGS_FILE $SETTINGS_FILE
}

function modify_user()
{
    modify_home /home

    if [[ "${TYPE_MACHINE}" == "cliprm" && -z "${CLIP_ONLY}" ]]
    then
    	modify_home /home/rm_h
    	modify_home /home/rm_b
    fi

    ${USERMOD} -p ${ENCRYPTED_PASSWORD} ${CURRENT_USER}
    [ $? -ne 0 ] && error "Erreur dans la modification de l'utilisateur"

    XDIALOG_MESSAGE="Compte modifié"
    XDIALOG_TITLE="Modification de l'utilisateur ${CURRENT_USER}"
   
    ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --msgbox "${XDIALOG_MESSAGE}" 6 80
}

####################################
############ MAIN CODE #############
####################################

if [ ! $# -eq 2 ]
then
    error "Parametres LOGIN et TYPE manquants"
fi

LOGIN=$1
TYPE_MACHINE=$2

get_user_connected

if [ "${LOGIN}" != "_admin" -a "${LOGIN}" != "_audit" -a "${CURRENT_USER}" != "${LOGIN}" ]
then
    error "Utilisateur à modifier != Utilisateur connecté"
fi

if ${GRPS} "${LOGIN}" | ${GREP} -e "\<admin\>" 1>/dev/null; then 
	CLIP_ONLY="y"
else if ${GRPS} "${LOGIN}" | ${GREP} -e "\<audit\>" 1>/dev/null; then 
	CLIP_ONLY="y"
fi
fi

get_old_password 

get_new_password 

encrypt_password

modify_user

exit 0
