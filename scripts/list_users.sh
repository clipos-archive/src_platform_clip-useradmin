#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

###################################################################################
#
# EADS DCS
#
# Create users 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version
# 2 as published by the Free Software Foundation.
#
####################################################################################

# Modified to use common functions from user_common.sh
# 2008/03/27 - Vincent Strubel <clipos@ssi.gouv.fr>

SCRIPT_NAME="LIST_USER"
XDIALOG_ERROR_TITLE="Listing des utilisateurs"

source /sbin/user_common.sh || exit 1

####################################
############ Util code #############
####################################

function display_users()
{
    USERS=`${CAT} /etc/passwd | ${GREP} home | ${GREP} user | ${AWK} -F':' '{print $1}'`
    USERS_NBR=`${CAT} /etc/passwd | ${GREP} home | ${WC} -l`
    typeset -i BOXSIZE=${USERS_NBR}+${USERS_NBR} 

    XDIALOG_MESSAGE="$USERS"
    XDIALOG_TITLE="Liste des utilisateurs"
   
    ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --msgbox "${XDIALOG_MESSAGE}" ${BOXSIZE} 40
}

####################################
############ MAIN CODE #############
####################################

get_user_connected

display_users

exit 0
