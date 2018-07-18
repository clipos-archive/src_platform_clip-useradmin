#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

###################################################################################
#
# EADS DCS
#
# Unlock user account
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#
####################################################################################

# Modified to use common functions from user_common.sh
# 2008/03/27 - Vincent Strubel <clipos@ssi.gouv.fr>

SCRIPT_NAME="UNLOCK_USER"
XDIALOG_ERROR_TITLE="Déverrouillage de l'utilisateur"

source /sbin/user_common.sh || exit 1

####################################
############ Util code #############
####################################

function unlock_user()
{
    ${USERMOD} -U ${LOGIN}
    [ $? -ne 0 ] && error "Erreur dans le verrouillage de l'utilisateur"

    XDIALOG_MESSAGE="Compte déverrouillé"
    XDIALOG_TITLE="Déverrouillage de l'utilisateur ${LOGIN}"
   
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
    error "Utilisateur à déverrouiller = Utilisateur connecté"
fi

unlock_user

exit 0
