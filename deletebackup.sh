#!/bin/bash

# 백업 파일명은 hostname 으로 생성한다
export BACKUP_DB=$(/usr/bin/hostname)

# 백업 경로
export BASE_DIR="/data/backup/${BACKUP_DB}"

# 오래된 백업 삭제 (20일 지난 것)
if [ -d "${BASE_DIR}" ]; then
    /usr/bin/find "${BASE_DIR}" -name "${BACKUP_DB}*" -mtime +20 -exec rm -rf "{}" +
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Old backup delete complete"
else
    echo "Error: ${BASE_DIR} does not exist"
fi
