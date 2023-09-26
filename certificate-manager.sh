################################################################################
#                                   TODO                                       #
################################################################################
# TODO :
#   adapter le script à plusieurs DNS
#   adapter le script à MUTEX

################################################################################
#                                  GLOBAL                                      #
################################################################################

# Chemin du dossier racine
ROOT_DIR=/Users/brebis/openssl

# Chemin du dossier contenant l'ensemble des certificats
CM_DIR=$ROOT_DIR/Certificate-Manager

# Dossier contenant les informations des CA racines
CA_ROOT_DIR=$CM_DIR/root-certification-authority

# Dossier contenant les informations des CA intermédiaires
CA_SUB_DIR=$CM_DIR/sub-certification-authority

# Dossier contenant les informations des utilisateurs
USER_DIR=$CM_DIR/users

# Fichier de configuration des CA racines
CA_ROOT_CONFIG=$CA_ROOT_DIR/openssl.cnf

# Fichier de configuration des CA intermédiaires
CA_SUB_CONFIG=$CA_SUB_DIR/openssl.cnf


################################################################################
#                                 FUNCTION                                     #
################################################################################

#############
#           #
#   Tools   #
#           #
#############

# Fonction d'initialisation de l'utilisation
function initialisation_utilisation {
    USE=""
    case "$1" in
        "racine")
            USE=${CA_ROOT_DIR}
            ;;
        "intermédiaire")
            USE=${CA_SUB_DIR}
            ;;
        "utilisateur")
            USE=${USER_DIR}
            ;;
        *)
            echo "ERROR : Usage invalide !"
            echo ""
            exit 1
            ;;
    esac
}

# fonction d'initialisation du nom
function initialisation_nom {

    # choix du nom
    NAME=""

    while [[ -z "$NAME" ]]; do
        echo "Quel est le nom à attribuer ?"
        read -r NAME
        if [[ -e ""${USE}"/private/"${NAME}".key" ]]; then
            echo "ERROR : Nom déjà utilisé !"
            echo ""
            NAME=""
        fi
    done
}

# Fonction d'initialisation de la clé privée
function initialisation_cle_priv {

    # Choix de la longueur de la clé
    KEYLEN=0
    while [[ $KEYLEN -ne 1024 && $KEYLEN -ne 2048 && $KEYLEN -ne 4096 ]]; do
        echo "Quelle longueur de clé souhaitez-vous utiliser (1024, 2048, 4096) ?"
        echo "Recommandations : utilisateur -> 2048, AC / AC intermédiaire -> 4096"
        read -r TMP
        case "$TMP" in
            1024 | 2048 | 4096 )
                KEYLEN=$TMP
                ;;
            "")
                # Valeur par défaut pour les CA et CA intermédiaires
                if [[ "${USE}" == "${CA_ROOT_DIR}" || "${USE}" == "${CA_SUB_DIR}" ]]; then
                    KEYLEN=4096
                else
                    # Valeur par défaut pour les utilisateurs
                    KEYLEN=2048
                fi
                ;;
            *)
                echo "ERROR : Valeur invalide !"
                echo ""
                KEYLEN=0
                ;;
        esac
    done
}

# Fonction d'initialisation de la durée de validité du certificat
function initialisation_validite {

    # Choix de la durée de validité du certificat
    VALIDITY=0
    while [[ $VALIDITY -ne 730 && $VALIDITY -ne 1825 && $VALIDITY -ne 3650 ]]; do
        echo "Quelle durée de validité de certificat souhaitez-vous appliquer ?"
        echo "Les valeurs possibles sont 2, 5, 10 ans (default=5) :"
        read -r TMP
        case "$TMP" in
            2)
                VALIDITY=730
                ;;
            5|"")
                VALIDITY=1825
                ;;
            10)
                VALIDITY=3650
                ;;
            *)
                echo "ERROR : Valeur invalide !"
                echo ""
                VALIDITY=0
                ;;
        esac
    done
}

# Fonction d'initialisation du choix de CA / CA intermédiaire pour signer le CSR
function initialisation_CA_valide {

    CA=""
    if [[ "${USE}" == "${CA_SUB_DIR}" ]]; then
        # Validation par CA
        while [[ -z "$CA" ]]; do
            echo "Quelle autorité de certification racine souhaitez-vous utiliser ?"
            read -r CA
            if ! [[ -e ""${CA_ROOT_DIR}"/private/"${CA}".key" && -e ""${CA_ROOT_DIR}"/certs/"${CA}".pem" ]]; then
                echo "ERROR : Autorité de certification racine invalide !"
                echo ""
                CA=""
            fi
        done
    else
        # Validation par CA intermédiaire
        while [[ -z "$CA" ]]; do
            echo "Quelle autorité de certification intermédiaire souhaitez-vous utiliser ?"
            read -r CA
            if [[ ! -e ""${CA_SUB_DIR}"/private/"${CA}".key" || ! -e ""${CA_SUB_DIR}"/certs/"${CA}".pem" ]]; then
                echo "ERROR : Autorité de certification intermédiaire invalide !"
                echo ""
                CA=""
            fi
        done
    fi
}

#####################
#                   #
#    Génération     #
#                   #
#####################

# Fonction initialisation d'un nouveau dossier de gestion de CA
function creation_nouveau_CA {

    # Vérification installation openssl
    echo "Vérification des prérequis..."
    if [[ ! $(openssl version) ]]; then
        echo "ERROR : Openssl n'est pas installé !"
        exit 1
    fi

    # Vérification du choix du dossier ROOT
    echo "Avez-vous modifié à votre convenance la variable ROOT_DIR avec le bon chemin d'installation (y/N) ?"
    read -r TMP
    if [[ "${TMP}" != "y" && "${TMP}" != "Y" ]]; then
        echo "Dans ce cas, veuillez modifier cette variable avec le chemin d'installation voulu et recommencez l'installation !"
        exit 1
    fi

    # Création du nouveau dossier de gestion de certificats
    echo "Création d'un nouveau dossier de gestion de certificats..."
    echo ""

    # Dossier racine
    mkdir "$ROOT_DIR"

    # Dossier CA
    mkdir -p ${CA_ROOT_DIR}/{certs,csr,newcerts,private}
    touch ${CA_ROOT_DIR}/index
    openssl rand -hex 16 > "${CA_ROOT_DIR}"/serial

    # Dossier CA intermédiaire
    mkdir -p ${CA_SUB_DIR}/{certs,csr,newcerts,private}
    touch ${CA_SUB_DIR}/index
    openssl rand -hex 16 > "${CA_SUB_DIR}"/serial

    # Dossier utilisateurs
    mkdir -p ${USER_DIR}/{certs,chained,csr,newcerts,pkcs12,private}

    echo "INFO : Veuillez placer les fichiers de configurations CA et CA intermédiaire respéctivement dans ${CA_ROOT_DIR}/openssl.cnf et ${CA_SUB_DIR}/openssl.cnf"
    echo "Dossier de gestion des certificats effectué !"
    exit 0
}

# Fonction de réinitialisation du dossier CA
function reinitialiser_CA {

    # Confirmation de réinitialisation
    echo "Etes-vous sûr de vouloir réinitialiser le dossier ${CM_DIR} contenant l'ENSEMBLE des certificats (y/N) ?"
    read -r TMP
    # Confirmation validée
    if [[ "${TMP}" == "y" || "${TMP}" == "Y" ]]; then

        # Sauvegarde du dossier Certificate-Manager
        tar -zcf Certificate-Manager-"$(date +%d%m%y)".tar.gz "${CM_DIR}"

        # Sauvegarde des fichiers de configurations
        # A modifier à convenance
        mv $CA_ROOT_DIR/openssl.cnf $ROOT_DIR/root-openssl.cnf
        mv $CA_SUB_DIR/openssl.cnf $ROOT_DIR/sub-openssl.cnf

        # Serveur
        rm -rf ${USER_DIR}/{certs,chained,csr,newcerts,pkcs12,private}/*

        # CA intermédiaire
        echo "Voulez-vous également supprimer l'autorité de certification intermédiaire (y/N) ?"
        read -r TMP
        # Confirmation de suppression
        if [[ "${TMP}" == "y" || "${TMP}" == "Y" ]]; then
            rm -rf ${CA_SUB_DIR}/{certs,csr,newcerts,private}/*
        else
            rm -rf ${CA_SUB_DIR}/{csr,newcerts}/*
        fi
        # Réinitialisation du reste du CA intermédiaire
        rm -f ${CA_SUB_DIR}/index* ${CA_SUB_DIR}/serial.*
        touch ${CA_SUB_DIR}/index


        # CA
        echo "Voulez-vous également supprimer l'autorité de certification racine (y/N) ?"
        read -r TMP
        # Confirmation de suppression
        if [[ "${TMP}" == "y" || "${TMP}" == "Y" ]]; then
            rm -rf ${CA_ROOT_DIR}/{certs,csr,newcerts,private}/*
        else
            rm -rf ${CA_ROOT_DIR}/{csr,newcerts}/*
        fi
        # Réinitialisation du reste du CA racine
        rm -f ${CA_ROOT_DIR}/index* ${CA_ROOT_DIR}/serial.*
        touch ${CA_ROOT_DIR}/index

        # Remise en place des fichiers de configurations
        mv $ROOT_DIR/root-openssl.cnf $CA_ROOT_DIR/openssl.cnf
        mv $ROOT_DIR/sub-openssl.cnf $CA_SUB_DIR/openssl.cnf

        echo "Réinitialisation du dossier de gestion des certificats effectué !"
    fi

    exit 0
}

# Fonction de génération de clé privée
function generation_cle_priv {

    # Initialisation de la longueur de la clé
    initialisation_cle_priv

    # Génération de la clé privée
    if [ "${USE}" == "${USER_DIR}" ]; then
        # Clé privée pour utilisateurs donc aucun chiffrement
        openssl genrsa -out "${USE}"/private/"${NAME}".key "${KEYLEN}"
    else
        # Clé privée pour AC et AC intermédiaire donc chiffrement aes256
        openssl genrsa -aes256 -out "${USE}"/private/"${NAME}".key "${KEYLEN}"
    fi
}

# Fonction de génération d'AC racine
function generation_AC_racine {
    clear
    echo "*****************************************************"
    echo "*                                                   *"
    echo "* Génération d'une autorité de certification racine *"
    echo "*                                                   *"
    echo "*****************************************************"

    # Initialisation
    initialisation_utilisation "racine"
    initialisation_nom

    # Génération de la clé privée
    generation_cle_priv

    # Génération certificat
    initialisation_validite
    openssl req -new -x509 -sha256 -days $VALIDITY\
        -key "${CA_ROOT_DIR}"/private/"${NAME}".key\
        -out "${CA_ROOT_DIR}"/certs/"${NAME}".pem\
        -config $CA_ROOT_CONFIG -extensions v3_ca

    exit 0
}

# Fonction de génération d'AC intermédiaire
function generation_AC_intermediaire {
    clear
    echo "************************************************************"
    echo "*                                                          *"
    echo "* Génération d'une autorité de certification intermédiaire *"
    echo "*                                                          *"
    echo "************************************************************"

    # Initialisation
    initialisation_utilisation "intermédiaire"
    initialisation_nom

    # Génération de la clé privée
    generation_cle_priv

    # Génération de la requete de signature de certificat
    initialisation_validite
    openssl req -new -sha256 -key "${CA_SUB_DIR}"/private/"${NAME}".key\
        -out "${CA_SUB_DIR}"/csr/"${NAME}".csr\
        -config $CA_SUB_CONFIG

    # Choix du CA pour signature
    echo "\n"
    initialisation_CA_valide

    # Signature du CSR et génération du certificat
    openssl ca -in "${CA_SUB_DIR}"/csr/"${NAME}".csr -days $VALIDITY -notext\
        -out "${CA_SUB_DIR}"/certs/"${NAME}".pem\
        -keyfile "${CA_ROOT_DIR}"/private/"${CA}".key\
        -cert "${CA_ROOT_DIR}"/certs/"${CA}".pem\
        -config $CA_SUB_CONFIG -extensions v3_intermediate_ca

    exit 0
}

# Fonction de génération d'un certificat pour utilisateurs
function generation_utilisateur {
    clear
    echo "***********************************************"
    echo "*                                             *"
    echo "* Génération d'un certificat pour utilisateur *"
    echo "*                                             *"
    echo "***********************************************"

    # Initialisation
    initialisation_utilisation "utilisateur"
    initialisation_nom

    # Génération de la clé privée
    generation_cle_priv

    # Génération de la requete de signature de certificat
    initialisation_validite
    openssl req -new -sha256 -key "${USER_DIR}"/private/"${NAME}".key\
        -out "${USER_DIR}"/csr/"${NAME}".csr

    # Choix du CA intermédiaire pour signature
    echo "\n"
    initialisation_CA_valide

    # Signature du CSR et génération du certificat
    openssl ca -in "${USER_DIR}"/csr/"${NAME}".csr -days $VALIDITY -notext\
        -out "${USER_DIR}"/certs/"${NAME}".pem\
        -keyfile "${CA_SUB_DIR}"/private/"${CA}".key\
        -cert "${CA_SUB_DIR}"/certs/"${CA}".pem\
        -config $CA_SUB_CONFIG -extensions server_cert

    # Options
    options_export_certificat_utilisateur

    exit 0
}


# Fonction gérant les options supplémentaires d'export des certificats utilisateurs
function options_export_certificat_utilisateur {
    # Options
    CHOIX=""
    echo "Souhaitez-vous chainer ce certificat (y/N) ?"
    read -r CHOIX
    if [[ "${CHOIX}" != "n" && "${CHOIX}" != "N" ]]; then
        cat "${USER_DIR}"/certs/"${NAME}".pem "${CA_SUB_DIR}"/certs/"${CA}".pem > "${USER_DIR}"/chained/chained-"${NAME}".pem
        echo "Le certificat chainé "${USER_DIR}"/chained/chained-"${NAME}".pem est disponible"
    fi
    echo ""

    echo "Souhaitez-vous exporter le certificat et sa clé privée au format PKCS12 (y/N) ?"
    read -r CHOIX
    if [[ "${CHOIX}" != "n" && "${CHOIX}" != "N" ]]; then
        openssl pkcs12 -inkey "${USER_DIR}"/private/"${NAME}".key\
            -in "${USER_DIR}"/certs/"${NAME}".pem\
            -export -out "${USER_DIR}"/pkcs12/"${NAME}".p12
        echo "L'export "${USER_DIR}"/pkcs12/"${NAME}".p12 est disponible"
    fi
}

#####################
#                   #
#   Visualisation   #
#                   #
#####################

# Fonction de Visualisation de certificats
function visualisation_certificats {
    clear
    echo "*********************************"
    echo "*                               *"
    echo "* Visualisation d'un certificat *"
    echo "*                               *"
    echo "*********************************"

    # Initialisation
    initialisation_utilisation "$1"

    NAME=""
    while [[ -z "$NAME" ]]; do
        echo "Quel est le nom du certificat à visualiser ?"
        read -r NAME
        if [[ ! -e ""${USE}"/certs/"${NAME}".pem" ]]; then
            echo "ERROR : Aucun certificat ne porte ce nom !"
            NAME=""
        fi
    done

    # Visualisation du certificat
    openssl x509 -in "${USE}"/certs/"${NAME}".pem -text -noout

    exit 0
}



################################################################################
#                                   MAIN                                       #
################################################################################

clear
echo "****************************************************"
echo "*                                                  *"
echo "*     Script de gestion des clés et certificats    *"
echo "*                                                  *"
echo "****************************************************"
echo "Choisissez l'opération que vous souhaitez effectuer :"

select CHOIX in \
    "Générer une autorité de certification racine"\
    "Générer une autorité de certification intermédiaire"\
    "Générer un certificat pour un utilisateur"\
    "Visualiser un certificat d'une autorité de certification racine"\
    "Visualiser un certificat d'une autorité de certification intermédiaire"\
    "Visualiser un certificat pour un utilisateur"\
    "Créer un nouveau dossier de gestion des certificats"\
    "Réinitialiser le dossier de gestion des certificats"\
    "Abandon"
do
    case ${CHOIX} in
        "Générer une autorité de certification racine")
            generation_AC_racine
            ;;
        "Générer une autorité de certification intermédiaire")
            generation_AC_intermediaire
            ;;
        "Générer un certificat pour un utilisateur")
            generation_utilisateur
            ;;
        "Visualiser un certificat d'une autorité de certification racine")
            visualisation_certificats "racine"
            ;;
        "Visualiser un certificat d'une autorité de certification intermédiaire")
            visualisation_certificats "intermédiaire"
            ;;
        "Visualiser un certificat pour un utilisateur")
            visualisation_certificats "utilisateur"
            ;;
        "Créer un nouveau dossier de gestion des certificats")
            creation_nouveau_CA
            ;;
        "Réinitialiser le dossier de gestion des certificats")
            reinitialiser_CA
            ;;
        "Abandon")
            exit 0
            ;;
    esac
done
