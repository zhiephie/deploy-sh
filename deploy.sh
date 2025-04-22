#!/bin/bash

#####################      Variables     #############################

# Default to today's date (format: DDMMYYYY)
DEPLOY_DATE=$(date "+%d%m%Y")
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]{8}$ ]]; then
        DEPLOY_DATE="$arg"
    elif [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    fi
done

SOURCE_DIR="/apps/deploy/$DEPLOY_DATE/"
DEST_DIR="/apps/helpdesk/"
TMP_FILE="/tmp/copyfileslist.txt"

# Ownership settings
CHANGE_OWNERSHIP=0
USER='nginx'
GROUP='nginx'

##################### Confirmation Prompt #############################

echo "Deployment Date      : $DEPLOY_DATE"
echo "Source Directory     : $SOURCE_DIR"
echo "Destination Directory: $DEST_DIR"
if $DRY_RUN; then
    echo "Mode: DRY-RUN (No files will be copied or modified)"
fi

read -p "Do you want to proceed with the deployment? (yes/no) " yn

case $yn in
    yes ) echo "Starting deployment...";;
    no ) echo "Deployment aborted."; exit;;
    * ) echo "Invalid response. Exiting."; exit 1;;
esac

##################### Check Directories #############################

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "❌ Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "${DEST_DIR}" ]; then
    echo "Destination directory does not exist. Creating: $DEST_DIR"
    mkdir -p "${DEST_DIR}" || { echo "❌ Failed to create destination directory."; exit 1; }
fi

##################### Copy Process #############################

cd "${SOURCE_DIR}" || { echo "❌ Failed to access $SOURCE_DIR"; exit 1; }

find . -type f > "$TMP_FILE"

while read CURRENT_FILE_NAME; do
    DIRNAME=$(dirname "$CURRENT_FILE_NAME")
    RELATIVE_DIR="${DIRNAME#./}"

    # Remove previous backup if exists
    for filename in "${DEST_DIR}${RELATIVE_DIR}"/*.php.*; do
        if [ -f "${filename}" ]; then
            echo "🧹 Removing old backup: $filename"
            if ! $DRY_RUN; then rm -f "${filename}"; fi
        fi
    done

    # Rename current file as backup
    current_time="$(echo $DEPLOY_DATE | sed -E 's#(..)(..)(....)#\3.\2.\1#')"
    new_file="${CURRENT_FILE_NAME}.${current_time}"

    if [ -f "${DEST_DIR}${CURRENT_FILE_NAME}" ]; then
        echo "🗄️  Backing up ${CURRENT_FILE_NAME} → ${new_file}"
        if ! $DRY_RUN; then
            mv -f "${DEST_DIR}${CURRENT_FILE_NAME}" "${DEST_DIR}${new_file}"
        fi
    fi

    # Copy new file
    echo "📦 Deploying: ${CURRENT_FILE_NAME} → ${DEST_DIR}${CURRENT_FILE_NAME}"
    if ! $DRY_RUN; then
        cp --parents "${CURRENT_FILE_NAME}" "${DEST_DIR}"
        if [ $? -eq 0 ]; then
            echo "✅ File copied successfully."
        else
            echo "❌ Failed to copy: ${CURRENT_FILE_NAME}"
        fi
        sleep 1
    fi

done < "$TMP_FILE"

rm -f "$TMP_FILE"

##################### Permission Section #############################

if [ "$CHANGE_OWNERSHIP" -eq 1 ] && ! $DRY_RUN; then
    sudo chmod 775 -R "${DEST_DIR}"
    echo "🔐 Permissions set to 775 in ${DEST_DIR}"
fi

if ! $DRY_RUN; then
    sudo chown "${USER}:${GROUP}" -R "${DEST_DIR}"
    echo "👤 Ownership changed to ${USER}:${GROUP}"
fi

echo "🚀 Deployment process finished $(if $DRY_RUN; then echo '(dry-run mode)'; fi)"
