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

find . -type f | sed 's#^\./##' > "$TMP_FILE"

# Backup suffix: DDMMYYYY -> YYYY.MM.DD (the format rollback.sh expects)
BACKUP_SUFFIX="$(echo "$DEPLOY_DATE" | sed -E 's#(..)(..)(....)#\3.\2.\1#')"
TOTAL=$(wc -l < "$TMP_FILE")
COUNT=0
FAILED=0

while IFS= read -r CURRENT_FILE_NAME; do
    COUNT=$((COUNT + 1))
    TARGET="${DEST_DIR}${CURRENT_FILE_NAME}"
    BACKUP="${TARGET}.${BACKUP_SUFFIX}"

    # Remove this file's backups from previous deploys (other dates only).
    # Only this file's own backups: deleting every *.php.* in the directory also
    # removed the backups just made for sibling files, which broke rollback.
    for old in "${TARGET}".[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]; do
        if [ -f "$old" ] && [ "$old" != "$BACKUP" ]; then
            if ! $DRY_RUN; then rm -f "$old"; fi
        fi
    done

    # Back up the current file. Keep an existing backup of the same date so a
    # second run on the same day does not overwrite the pre-deploy original.
    ACTION="new"
    if [ -f "$TARGET" ]; then
        ACTION="update"
        if [ ! -e "$BACKUP" ] && ! $DRY_RUN; then
            mv -f "$TARGET" "$BACKUP"
        fi
    fi

    echo "📦 [$COUNT/$TOTAL] $ACTION ${CURRENT_FILE_NAME}"
    if ! $DRY_RUN; then
        if ! cp --parents "${CURRENT_FILE_NAME}" "${DEST_DIR}"; then
            echo "❌ Failed to copy: ${CURRENT_FILE_NAME}"
            FAILED=$((FAILED + 1))
        fi
    fi

done < "$TMP_FILE"

##################### Permission Section #############################

# Only the deployed files (and their backups), not the whole tree: DEST_DIR also
# holds uploads/attachments, and a recursive chown/chmod over them is slow.
if ! $DRY_RUN; then
    cd "${DEST_DIR}" || { echo "❌ Failed to access $DEST_DIR"; exit 1; }
    if [ "$CHANGE_OWNERSHIP" -eq 1 ]; then
        xargs -r -d '\n' sudo chmod 775 < "$TMP_FILE"
        echo "🔐 Permissions set to 775 on deployed files"
    fi
    # files, their backups, and every parent directory (cp --parents may create new ones)
    { cat "$TMP_FILE"; sed "s#\$#.${BACKUP_SUFFIX}#" "$TMP_FILE"
      awk -F/ '{p=""; for (i=1; i<NF; i++) {p = p (i>1 ? "/" : "") $i; print p}}' "$TMP_FILE" | sort -u; } \
        | while IFS= read -r f; do [ -e "$f" ] && printf '%s\n' "$f"; done \
        | xargs -r -d '\n' sudo chown "${USER}:${GROUP}"
    echo "👤 Ownership changed to ${USER}:${GROUP} on deployed files"
fi

rm -f "$TMP_FILE"

if [ "$FAILED" -gt 0 ]; then
    echo "⚠️  $FAILED of $TOTAL files failed to copy"
fi

echo "🚀 Deployment process finished $(if $DRY_RUN; then echo '(dry-run mode)'; fi)"
