#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

###################################################################################
#
# EADS DCS
#
# Delete user
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#
####################################################################################

# Modified to use common functions from user_common.sh
# 2008/03/27 - Vincent Strubel <clipos@ssi.gouv.fr>

SCRIPT_NAME="DELETE_USER"
XDIALOG_ERROR_TITLE="Suppression de l'utilisateur"

source /sbin/user_common.sh || exit 1

####################################
############ Util code #############
####################################

function remove_home()
{
    local CRYPT_FILE="$1/parts/$LOGIN.part"
    local KEY_FILE="$1/keys/$LOGIN.key"
    local SETTINGS_FILE="$1/keys/$LOGIN.settings"

    ${RM} -f "${CRYPT_FILE}"
    ${RM} -f "${KEY_FILE}"
    ${RM} -f "${SETTINGS_FILE}"
}

function clean_ssh_keys()
{
    ${GREP} -v ${LOGIN}@clip /home/${1}/.ssh/authorized_keys > /home/${1}/.ssh/authorized_keys_bis 
    ${CP} /home/${1}/.ssh/authorized_keys_bis /home/${1}/.ssh/authorized_keys
    ${RM} /home/${1}/.ssh/authorized_keys_bis
}

function delete_user()
{
    [[ "${LOGIN}" == "root" ]] && error "Utilisateur inconnu"
    [ ! -d "/etc/tcb/${LOGIN}" ] && error "Utilisateur inconnu"

    # Remove the key from authorized_keys if necessary
    clean_ssh_keys adminclip
    clean_ssh_keys auditclip

    remove_home /home

    if [ "${TYPE_MACHINE}" = "cliprm" ]
    then
    	remove_home /home/rm_h
    	remove_home /home/rm_b
    fi

    ${USERDEL} ${LOGIN}
    [ $? -ne 0 ] && error "Erreur dans la suppression de l'utilisateur"

    XDIALOG_MESSAGE="Compte supprimé"
    XDIALOG_TITLE="Suppression de l'utilisateur ${LOGIN}"
   
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

if [ "${CURRENT_USER}" = "${LOGIN}" ]
then
    error "Utilisateur à supprimer = Utilisateur connecté"
fi

delete_user

exit 0
