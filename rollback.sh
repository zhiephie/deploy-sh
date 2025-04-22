#!/bin/bash

#####################      Variables     #############################

DEST_DIR="/apps/helpdesk/"
TMP_FILE="/tmp/rollbackfiles.txt"

# Default to today's date
ROLLBACK_DATE=$(date "+%Y.%m.%d")
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
        ROLLBACK_DATE="$arg"
    elif [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    fi
done

echo "Rollback files in $DEST_DIR to backup date: $ROLLBACK_DATE"
if $DRY_RUN; then
    echo "Mode: DRY-RUN (no actual changes will be made)"
fi

read -p "Are you sure you want to proceed with this rollback? (yes/no) " yn

case $yn in
    yes ) echo "Starting rollback...";;
    no ) echo "Rollback aborted."; exit;;
    * ) echo "Unrecognized input. Exiting."; exit 1;;
esac

########### Rollback logic #################

cd "${DEST_DIR}" || { echo "Failed to access $DEST_DIR"; exit 1; }

find . -type f -name "*.$ROLLBACK_DATE" > "$TMP_FILE"

if [ ! -s "$TMP_FILE" ]; then
    echo "❌ No backup files found with date $ROLLBACK_DATE"
    rm -f "$TMP_FILE"
    exit 1
fi

while read BACKUP_FILE; do
    ORIGINAL_FILE="${BACKUP_FILE%.$ROLLBACK_DATE}"

    if [ -f "$BACKUP_FILE" ]; then
        echo "Rolling back: $ORIGINAL_FILE ← $BACKUP_FILE"
        if $DRY_RUN; then
            echo "🔍 Dry-run: would replace $ORIGINAL_FILE with $BACKUP_FILE"
        else
            mv -f "$BACKUP_FILE" "$ORIGINAL_FILE"
            echo "✅ Rolled back: $ORIGINAL_FILE"
        fi
    else
        echo "❌ Backup file not found: $BACKUP_FILE"
    fi
done < "$TMP_FILE"

rm -f "$TMP_FILE"
echo "✅ Rollback process completed $(if $DRY_RUN; then echo '(dry-run mode)'; fi)"
