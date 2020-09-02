#! /bin/bash

# SCRIPT SHOULD NOT BE USED IN A PRODUCTION ENV!!!
# Refrence README for more info



#Script will install sshpass if not avaiable on runtime
if [ $(dpkg-query -W -f='${Status}' sshpass 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo 'sshpass package not found, installing now...'
    apt-get install -y sshpass;
fi

REGEX_HELP='((-{1,2})([Hh]$|[Hh][Ee][Ll][Pp]))'
REGEX_DOMAIN='([a-z0-9|-]+\.)*[a-z0-9|-]+\.[a-z]+'
REGEX_IP='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
USERNAME=''
REMOTE=''
CLIENT_PASS=''
ENCRYPT_TYPE=''
SAVE_DIR=''
KEY_COMMENT=''
SSH_KEYGEN_CMD='ssh-keygen '
SSH_COPY_ID_CMD='sshpass '

help () {
    __usage="
    Options:
    -u, --user                Username for remote client where public key will be copied
    -r, --remote              Remote client address where public key will be copied to
    -p, --password            *optional* Remote client password where public key will be copied
    -t, --type                *optional* SSH host key encryption algorithm options;
                                dsa | ecdsa | ed25519 | rsa (Defaults to rsa) 
    -f, --file                *optional* Location where SSH keys will be stored, default: ~/.ssh/id_rsa
    -c, --comment             *optional* Add a SSH Public Key Comment
    " 
    echo "$__usage"
    exit 0
}

check_domain_format () {
    #check if the remote acess address fits the RFC 1035 or 1918 scheme for IP / domain name
    if [[ $1 =~ $REGEX_DOMAIN ]]; then 
        REMOTE=$1

    elif [[ $1 =~ $REGEX_IP ]]; then
        REMOTE=$1
    else
        echo 'Unable to determine remote device access address much match RFC 1035 or RFC 1918 structure.'
        exit 1
    fi
}

get_encrpt_type () {
    case $1 in 
        dsa)
            ENCRYPT_TYPE=dsa ;;
        ecdsa)
            ENCRYPT_TYPE=ecdsa ;;
        ed25519)
            ENCRYPT_TYPE=ed25519 ;;
        rsa)
            ENCRYPT_TYPE=rsa ;;
        *)
            ENCRYPT_TYPE=rsa
            echo 'Defaulting to RSA based SSH key encryption ...' ;;
    esac

}

# function checks to see if username / remoete domain left empty
required_flags () {
    if [[ "$USERNAME" == "" || "$REMOTE" == "" ]]; then
    echo "ERROR: Options -u and -r require arguments." >&2
    exit 1
    fi
}

# checks to see if custom key dir provided if not default ssh path is set
is_save_dir_empty () {

    case "$1" in
        "")
            SAVE_DIR=$HOME/.ssh/id_rsa ;;
        *) 
            SAVE_DIR=$(sed 's/~/$HOME/g' <<< "$1") ;;
    esac

    echo "$SAVE_DIR"
}

# check to see if key is still located in designated save location
is_key_avail () {
    if [[ ! -e "$1" ]]; then
        echo 'Unable to locate SSH private key, check permissions requirements and try again'
        exit 0
    fi
}

if [[ "$1" =~ $REGEX_HELP ]]; then
    help; exit 1
else
while [[ $# -gt 0 ]]; do
    opt="$1"
    shift;
    current_arg="$1"
    if [[ "$current_arg" =~ ^-{1,2}.* ]]; then
    echo "WARNING: You may have left an argument blank. Double check your command." 
    fi
    case "$opt" in
    "-u"|"--user"      ) USERNAME="$1"; shift;;
    "-r"|"--remote"     ) check_domain_format "$1"; shift;;
    "-p"|"--password"     ) CLIENT_PASS="$1"; shift;; 
    "-t"|"--type"     ) ENCRYPT_TYPE="$1"; shift;;
    "-f"|"--file"     ) SAVE_DIR="$1"; shift;;
    "-c"|"--comment"   ) KEY_COMMENT="$1"; shift;;
    *                   ) echo "ERROR: Invalid option: \""$opt"\"" >&2
                            exit 1;;
    esac
done
# run encryption type checker once flags read
get_encrpt_type "$ENCRYPT_TYPE"
fi

required_flags
is_save_dir_empty "$SAVE_DIR"

SSH_KEYGEN_CMD+='-t '"$ENCRYPT_TYPE"' -f '"$SAVE_DIR"' <<< y -C '"$KEY_COMMENT"' -q -N "" 2>&1 >/dev/null'
eval $SSH_KEYGEN_CMD

# check is newly created file exsists
is_key_avail "$SAVE_DIR"

SSH_COPY_ID_CMD+='-p '"'$CLIENT_PASS'"' ssh-copy-id -i '"$SAVE_DIR"' -o StrictHostKeyChecking=no '"$USERNAME"'@'"$REMOTE"''
eval $SSH_COPY_ID_CMD