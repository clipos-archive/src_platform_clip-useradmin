#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

###################################################################################
#
# EADS DCS
#
# Create user
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
# Modified to allow for bigger partitions and to avoid asking for a SSH passphrase
# 2009/02/03 - Olivier Levillain <clipos@ssi.gouv.fr>

ZERO_DEVICE="/dev/zero"
RANDOM_DEVICE="/dev/urandom"

CRYPTO_ROOT="/mnt/cdrom"
CONF_FILE="/etc/conf.d/usermgmt"

MIN_PARTSIZE=8
SPARE=128
DEFAULT_TOTAL_PARTSIZE=2048


source /lib/clip/userkeys.sub || exit 1

SCRIPT_NAME="CREATE_USER"
XDIALOG_ERROR_TITLE="Création d'utilisateur"

source /sbin/user_common.sh || exit 1

####################################
############ Util code #############
####################################

function cleanup()
{
    ${MOUNT} | ${GREP} "/home/${LOGIN}" >/dev/null 2>&1 && ${UMOUNT} "/home/${LOGIN}" 		
    [ -e "/dev/mapper/${LOGIN}" ] && ${CRYPTSETUP} remove "${LOGIN}"
    ${LOSETUP} -a | ${GREP} ${LOGIN} >/dev/null 2>&1 && ${LOSETUP} -d /dev/loop7 		
}

function clean_ssh_keys()
{
    if [ -e /home/${1}/.ssh/authorized_keys ]
    then
      ${GREP} -v ${LOGIN}@clip /home/${1}/.ssh/authorized_keys > /home/${1}/.ssh/authorized_keys_bis
      ${CP} /home/${1}/.ssh/authorized_keys_bis /home/${1}/.ssh/authorized_keys
      ${RM} /home/${1}/.ssh/authorized_keys_bis
    fi
}

function rollback()
{
    case "${USER_TYPE}" in
	"core_admin")
	    clean_ssh_keys adminclip
            ;;
	"core_audit")
	    clean_ssh_keys auditclip
	    ;;
	"priv_user")
	    clean_ssh_keys auditclip
	    clean_ssh_keys adminclip
	    ;;
	*)
	    ;;
    esac

    if [ "${TYPE_MACHINE}" = "cliprm" ]
    then
       delete_file "/home/rm_h/parts/${LOGIN}.part"
       delete_file "/home/rm_h/keys/${LOGIN}.key"
       delete_file "/home/rm_h/keys/${LOGIN}.settings"
       delete_file "/home/rm_b/parts/${LOGIN}.part"
       delete_file "/home/rm_b/keys/${LOGIN}.key"
       delete_file "/home/rm_b/keys/${LOGIN}.settings"
    fi
    delete_file "/home/parts/${LOGIN}.part"
    delete_file "/home/keys/${LOGIN}.key"
    delete_file "/home/keys/${LOGIN}.settings"
    delete_file "/home/id_rsa.pub"

    cleanup

    [ -d "/home/${LOGIN}" ] && ${RMDIR} "/home/${LOGIN}"

    delete_file "/home/${LOGIN}.part"
    delete_file "/home/${LOGIN}.key"
    delete_file "/home/${LOGIN}.settings"

    [ -d /etc/tcb/${LOGIN} ] && ${USERDEL} ${LOGIN}
}

function error_rollback()
{
	rollback
	error "${1}"
}

function get_user_type()
{
    if [ "x"${AUTHORITY}  = "x" ]
    then
    	echo "Entrez le type de l'utilisateur (core_admin, core_audit ou user) : "
    	while read USER_TYPE
	do
   	  if [ "${USER_TYPE}" != "core_admin" -a "${USER_TYPE}" != "core_audit" -a "${USER_TYPE}" != "user" ]
	  then
	  	echo "Choix invalide ! Vous avez le choix entre core_admin, core_audit ou user"
	  else
	  	break
	  fi
	done
    else
      XDIALOG_MESSAGE="Type de l'utilisateur :"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"
   
      if [[ "${ALLOW_PRIV_USER}" == "yes" ]]; then 
	      USER_TYPE=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --no-tags --radiolist "${XDIALOG_MESSAGE}" 16 60 3 "core_admin" "Administrateur du socle" 1 "core_audit" "Auditeur du socle" 2 "user" "Utilisateur" 3 "priv_user" "Utilisateur privilégié" 4 2>&1)
	      [ $? -ne 0 ] && error "Erreur dans le choix du type de l'utilisateur"
      else
	      USER_TYPE=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --no-tags --radiolist "${XDIALOG_MESSAGE}" 16 60 2 "core_admin" "Administrateur du socle" 1 "core_audit" "Auditeur du socle" 2 "user" "Utilisateur" 3 2>&1)
	      [ $? -ne 0 ] && error "Erreur dans le choix du type de l'utilisateur"
      fi

      	
    fi
}


function check_free_disk()
{
    FREESPACE_NEEDED="${1}"
    if [ "x"${FREESPACE_NEEDED} = "x" ]; then
	FREESPACE_NEEDED="0"
    fi

    MB_AVAILABLE=$(( ( $( df /home | grep /home | sed "s/[^ ]\+ \+[^ ]\+ \+[^ ]\+ \+\([0-9]\+\) \+.*/\1/" ) / 1024 ) - (${SPARE} + ${MIN_PARTSIZE}) ))
    if [ "x"${MB_AVAILABLE} = "x" ]; then
	error "Erreur inattendue lors de la vérification de l'espace disponible."
    fi
    if [ ${MB_AVAILABLE} -lt ${FREESPACE_NEEDED} ]; then
	error "Pas assez d'espace disque disponible."
    fi
}


function get_user_partitions_size()
{
    MIN=$(( ${MIN_PARTSIZE} * 2 ))

    check_free_disk "${MIN}"
    if [ ${MB_AVAILABLE} -lt ${DEFAULT_TOTAL_PARTSIZE} ]; then
        DEFAULT=$MB_AVAILABLE
    else
    	DEFAULT=${DEFAULT_TOTAL_PARTSIZE}
    fi
	

    if [ "x"${AUTHORITY}  = "x" ]
    then
    	echo "Entrez la taille totale réservée à l'utilisateur pour RM_B et RM_H (en Mo) [$MIN-$MB_AVAILABLE] : "
    	while read TOTAL_SIZE
	do
	  if [ ${TOTAL_SIZE} -lt ${MIN} -o ${PARTITION_SIZE} -gt ${MB_AVAILABLE} ]
	  then
	      echo "Choix invalide ! Vous avez le choix entre ${MIN} et ${MB_AVAILABLE}"
	  else
	      break
	  fi
	done
    else    
      XDIALOG_MESSAGE="Taille totale réservée à l'utilisateur pour RM_B et RM_H en Mo :"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"
   
      TOTAL_SIZE=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --wrap --title "${XDIALOG_TITLE}" --rangebox "${XDIALOG_MESSAGE}" 10 60 "${MIN}" "${MB_AVAILABLE}" "${DEFAULT}" 2>&1)
      [ $? -ne 0 ] && error "Erreur dans le choix de la taille des partitions"
    fi
}


function get_rm_size_repartition()
{
    MAX=$(( $TOTAL_SIZE - $MIN_PARTSIZE ))
    if [ "x${MIN_PARTSIZE}" = "x${MAX}" ]; then
      RMB_PARTSIZE=$MIN_PARTSIZE
      RMH_PARTSIZE=$MIN_PARTSIZE
      return
    fi
    DEFAULT=$(( $TOTAL_SIZE / 2 ))

    if [ "x"${AUTHORITY}  = "x" ]
    then
    	echo "Parmi les ${TOTAL_SIZE} Mo alloues à l'utilisateur, combien faut-il en réserver pour RM_B (en Mo) [$MIN_PARTSIZE-$MAX] ? "
    	while read RMB_PARTITION
	do
	  if [ ${RMB_PARTSIZE} -lt ${MIN_PARTSIZE} -o ${PARTITION_SIZE} -gt ${MAX} ]
	  then
	      echo "Choix invalide ! Vous avez le choix entre ${MIN_PARTSIZE} et ${MAX}"
	  else
	      break
	  fi
	done
    else    
      XDIALOG_MESSAGE="Parmi les ${TOTAL_SIZE} Mo alloués à l'utilisateur, combien faut-il en réserver pour RM_B (en Mo) ?"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"
   
      RMB_PARTSIZE=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --wrap --title "${XDIALOG_TITLE}" --rangebox "${XDIALOG_MESSAGE}" 10 60 "${MIN_PARTSIZE}" "${MAX}" "${DEFAULT}" 2>&1)
      [ $? -ne 0 ] && error "Erreur dans le choix de la répartition des partitions"
    fi
    RMH_PARTSIZE=$(( $TOTAL_SIZE - $RMB_PARTSIZE ))
}



function get_password()
{
    if [ "x"${AUTHORITY}  = "x" ]
    then
    	echo "Entrez le mot de passe de l'utilisateur : "
    	read -rst 30 PASSPHRASE
    	echo "Entrez de nouveau le mot de passe de l'utilisateur : "
    	read -rst 30 PASSPHRASE_BIS
    else 
      XDIALOG_MESSAGE="Veuillez saisir le mot de passe du compte utilisateur :"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"
      local pass

      pass=$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${XDIALOG_TITLE}" --inputbox "${XDIALOG_MESSAGE}" 10 60 2>&1)
      [ $? -ne 0 ] && error "Erreur dans la saisie du mot de passe"
      PASSPHRASE="$(passwd_check_loop "${pass}")"
      [[ -z "${PASSPHRASE}" ]] && error "Abandon de la saisie"

      XDIALOG_MESSAGE="Veuillez re-saisir le mot de passe du compte utilisateur :"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"

      PASSPHRASE_BIS="$(${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --password --title "${XDIALOG_TITLE}" --inputbox "${XDIALOG_MESSAGE}" 10 60 2>&1)"
      [ $? -ne 0 ] && error "Erreur dans la re-saisie du mot de passe"

      [ "${PASSPHRASE}" != "${PASSPHRASE_BIS}" ]  && error "Les deux mots de passe saisis sont différents"
    fi
}

function encrypt_password()
{
    ENCRYPTED_PASSWORD="$(PASS="${PASSPHRASE}" hash_password "PASS")"
    [ $? -ne 0 ] && error "Erreur dans le chiffrement du mot de passe"
}

function make_home()
{
    local PREFIX=$1
    local GEN_KEY=$2
    local HOST_KEY="${3}"
    local SIZE="${4}"
    local HOST_KEY2="${5}"

    [[ -z "${SIZE}" ]] && error_rollback "Erreur dans la taille de la partition"

    debug "Creation du home pour ${1}"

    cd /home
    local CRYPT_FILE="${LOGIN}.part"
    local KEY_FILE="${LOGIN}.key"
    local SETTINGS_FILE="${LOGIN}.settings"
    local KEY

    create_settings "${LOGIN}" "${SETTINGS_FILE}" || \
        error_rollback "Erreur dans la création du salt"

    ${DD} if="${ZERO_DEVICE}" of="${CRYPT_FILE}" bs=1M count="${SIZE}" >/dev/null 2>&1
    [ $? -ne 0 ] && error_rollback "Pas assez d'espace disque disponible"
    ${LOSETUP} /dev/loop7 "${CRYPT_FILE}"
    [ $? -ne 0 ] && error_rollback "Erreur dans l'appel a losetup"

    KEY=`${TR} -cd [:graph:] < ${RANDOM_DEVICE} | ${HEAD} -c 119`
    echo -n "${KEY}" | \
        PASS="${PASSPHRASE}" encrypt_stage2_key "${SETTINGS_FILE}" PASS "${KEY_FILE}" \
        || error_rollback "Erreur dans le chiffrement de la cle"

    echo -n "${KEY}" | ${CRYPTSETUP} -c aes-lrw-benbi -s 384 -h sha256 \
    						create "${LOGIN}" /dev/loop7
    [ $? -ne 0 ] && error_rollback "Erreur dans la création de device_mapper"

    [ ! -e "/dev/mapper/${LOGIN}" ] && error "/dev/mapper/${LOGIN} n'existe pas"

    ${MKE2FS} "/dev/mapper/${LOGIN}" >/dev/null 2>&1
    [ $? -ne 0 ] && error_rollback "Erreur dans la création du filesystem"

    ${MKDIR} -p "${LOGIN}"
    [ $? -ne 0 ] && error_rollback "Erreur dans la création du home directory"

    ${MOUNT} -o nosuid,nodev,noexec "/dev/mapper/${LOGIN}" "${LOGIN}"
    [ $? -ne 0 ] && error_rollback "Erreur dans le montage du device_mapper"

    ${CHOWN} "${LOGIN}" /home/"${LOGIN}"
    ${CHMOD} 700 "${LOGIN}"

    local umsk=$(umask)
    umask 0077
    if [ "${GEN_KEY}" = "y" ]
    then
	${MKDIR} "${LOGIN}/.ssh"
	${SSH_KEYGEN} -t rsa -b 2048 -f "${LOGIN}/.ssh/id_rsa" -C "${LOGIN}@clip" -N "" >/dev/null 2>&1
        [ $? -ne 0 ] && error_rollback "Erreur dans la génération des clés SSL de connexion"
	${CHOWN} -R "${LOGIN}" "${LOGIN}/.ssh"
	${CP} "${LOGIN}/.ssh/id_rsa.pub" .
    fi
    if [[ -n "${HOST_KEY}" && "${HOST_KEY}" != "-" ]]
    then
	echo -n "127.0.0.1 " > "${LOGIN}/.ssh/known_hosts"
	${AWK} '{print $1" "$2}' "${HOST_KEY}" >> "${LOGIN}/.ssh/known_hosts"
	${CHOWN} "${LOGIN}" "${LOGIN}/.ssh/known_hosts"
    fi
    if [[ -n "${HOST_KEY2}" && "${HOST_KEY2}" != "-" ]]
    then
	echo -n "127.0.0.1 " >> "${LOGIN}/.ssh/known_hosts"
	${AWK} '{print $1" "$2}' "${HOST_KEY2}" >> "${LOGIN}/.ssh/known_hosts"
	${CHOWN} "${LOGIN}" "${LOGIN}/.ssh/known_hosts"
    fi		
    umask "${umsk}"
    
    cleanup

    ${CHOWN} root:root "$CRYPT_FILE" "$KEY_FILE"
    ${CHMOD} 600 "$CRYPT_FILE" "$KEY_FILE"
    ${MV} "$CRYPT_FILE" "$PREFIX/parts/"
    ${MV} "$KEY_FILE" "$PREFIX/keys/"
    ${MV} "$SETTINGS_FILE" "$PREFIX/keys/"
    ${RMDIR} "$LOGIN"
}

function save_ssh_pubkey()
{
    [ ! -e /home/${1}/.ssh ] && ${MKDIR} /home/${1}/.ssh
    [ -e /home/${1}/.ssh/authorized_keys ] && ${CHMOD} 600 /home/${1}/.ssh/authorized_keys
    ${CAT} /home/id_rsa.pub >> /home/${1}/.ssh/authorized_keys
    ${CHOWN} -R 0:0 /home/${1}/.ssh
    ${CHMOD} 755 /home/${1}/.ssh
    ${CHMOD} 644 /home/${1}/.ssh/authorized_keys
}


function create_user()
{
    [ -d /etc/tcb/${LOGIN} ] && error "Utilisateur deja existant"

    if [ "${USER_TYPE}" = "user" ]
    then
	${USERADD} -g crypthomes -d /home/user -p ${ENCRYPTED_PASSWORD} ${LOGIN}
	[ $? -ne 0 ] && error_rollback "Erreur dans l'ajout de l'utilisateur"
    else 
    	local grps="crypthomes"
	[[ "${USER_TYPE}" == "priv_user" || "${USER_TYPE}" == "core_admin" ]] \
		&& grps="crypthomes,mount_update"
	${USERADD} -g ${USER_TYPE} -G "${grps}" -d /home/user -p ${ENCRYPTED_PASSWORD} ${LOGIN}
	[ $? -ne 0 ] && error_rollback "Erreur dans l'ajout de l'utilisateur"
    fi

    case "${USER_TYPE}" in
	"core_admin")
	    make_home . "y" "/mounts/admin_root/etc/ssh/ssh_host_rsa_key.pub" "${MIN_PARTSIZE}"
	    ${CHOWN} -R 4000:4000 /home/adminclip
	    save_ssh_pubkey "adminclip"
	    ;;

	"core_audit")
	    make_home . "y" "/mounts/audit_root/etc/ssh/ssh_host_rsa_key.pub" "${MIN_PARTSIZE}"
	    ${CHOWN} -R 5000:5000 /home/auditclip
	    save_ssh_pubkey "auditclip"
	    ;;
	 "priv_user")
	    if [ "${TYPE_MACHINE}" = "cliprm" ]
	    then
		# Force smallish size for USERclip HOME, since it is not used for much...
	        make_home . "y" "/mounts/admin_root/etc/ssh/ssh_host_rsa_key.pub" "${MIN_PARTSIZE}" \
			"/mounts/audit_root/etc/ssh/ssh_host_rsa_key.pub"
	    	
		make_home rm_h "n" "-" "${RMH_PARTSIZE}"

	    	make_home rm_b "n" "-" "${RMB_PARTSIZE}"
	    else
	        make_home . "y" "/mounts/admin_root/etc/ssh/ssh_host_rsa_key.pub" "${TOTAL_SIZE}" \
			"/mounts/audit_root/etc/ssh/ssh_host_rsa_key.pub"
	    fi
	    save_ssh_pubkey "auditclip"
	    save_ssh_pubkey "adminclip"
	    ;; 	
	*)

	    if [ "${TYPE_MACHINE}" = "cliprm" ]
	    then
		# Force smallish size for USERclip HOME, since it is not used for much...
	        make_home . "n" "-" "${MIN_PARTSIZE}"
	    	
		make_home rm_h "n" "-" "${RMH_PARTSIZE}"

	    	make_home rm_b "n" "-" "${RMB_PARTSIZE}"
	    else
	        make_home . "n" "${TOTAL_SIZE}"
	    fi
	    ;;
    esac

    if [ "x"${AUTHORITY} = "x" ]
    then
    	echo "Utilisateur ${LOGIN} cree"
    else    
      XDIALOG_MESSAGE="Utilisateur créé"
      XDIALOG_TITLE="Création de l'utilisateur ${LOGIN}"
   
      ${USER_ENTER} -u "${CURRENT_UID}" -- ${DIALOG} "${AUTHORITY}" --title "${XDIALOG_TITLE}" --msgbox "${XDIALOG_MESSAGE}" 6 80
    fi

}

####################################
############ MAIN CODE #############
####################################

[[ -f "${CONF_FILE}" ]] && . "${CONF_FILE}"

if [ ! $# -eq 2 ]
then
    error "Parametres LOGIN et TYPE manquants"
fi

LOGIN=$1
TYPE_MACHINE=$2

XDIALOG_ERROR_TITLE="Erreur dans la création de ${LOGIN}"

get_user_connected

check_free_disk "${MIN_PARTSIZE}"

if [ "${CURRENT_USER}" = "${LOGIN}" ]
then
    error "Utilisateur à créer = Utilisateur connecté"
fi

get_user_type

if [[ "${USER_TYPE}" == "user" || "${USER_TYPE}" == "priv_user" ]]; then
    get_user_partitions_size
    if [[ "${TYPE_MACHINE}" == "cliprm" ]]; then
	    get_rm_size_repartition
    fi
fi
    
get_password 

encrypt_password

create_user

exit 0
