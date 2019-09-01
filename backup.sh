#!/bin/bash
[[ -z "$1" ]] && echo "Usage: ./backup.sh ROOT_BACKUP_DIR" && exit 1

CONTAINERS=(nzbget radarr sonarr transmission emby jackett)
BACKUP_DIR=$1/$(date -I)
BACKUP_ARCHIVE=backup-$(date -I).tar.gz
NUM_BACKUPS=2 # Only keep 2 days of backups

# Rclone backup directory (optional)
# Install rclone: https://rclone.org/downloads/
# To setup rclone for Google Drive: https://rclone.org/drive/
RCLONE_BACKUP_DIR="gdrive:HTPC"

# Backup all config volumes
mkdir -p $BACKUP_DIR && cd $BACKUP_DIR
for container in "${CONTAINERS[@]}"; do
    echo "Backing up volume for $container.."
    docker run --rm --volumes-from $container -v $(pwd):/backup alpine /bin/sh -c "cd /config && tar cf /backup/$container.tar *"
done

# Compress entire backup directory
echo "Compressing backup..."
tar cvzf $BACKUP_ARCHIVE *

# If rclone is installed, assume it's configured
if [[ `command -v rclone` ]]; then
    echo "Backing up via rclone..."

    # Copy to GDrive
    rclone copy $BACKUP_ARCHIVE $RCLONE_BACKUP_DIR

    # Delete all backups older than NUM_BACKUPS days from GDrive
    rclone --min-age "$NUM_BACKUPS"d delete $RCLONE_BACKUP_DIR
fi

echo "Cleaning up..."

# Move archive up and delete local backup directory
mv $BACKUP_ARCHIVE ..
cd ..
rm -rf $BACKUP_DIR

# Remove the "oldest" local backup
oldest=$(date -I --date="$(($NUM_BACKUPS+1)) days ago")
rm -f backup-$oldest.tar.gz

echo "Done!"
