#!/bin/bash

# 백업 파일명은 hostname 으로 생성한다
export BACKUP_DB=$(/usr/bin/hostname)

# 백업 경로
export BASE_DIR="/data/backup/${BACKUP_DB}"

# 로그 경로
export LOG_DIR="${BASE_DIR}/logs"

# 로그디렉토리 없으면 생성
/usr/bin/mkdir -p ${LOG_DIR}

# 백업 년도주차
export WEEK_OF_YEAR="$(date '+%Y%W')"

# 백업 요일-> 일:0, 월:1, 화:2, 수:3, 목:4, 금:5, 토:6
#export DAY_OF_WEEK="$(date '+%w')"

# 백업 년월일_시분초
export DATE_TIME="$(date '+%Y%m%d_%H%M%S')"

# 해당주차에 마지막 풀맥업이 존재 하는지 확인(압축파일은 제외)
export LAST_FULL_BACKUP_NM=$(/usr/bin/ls ${BASE_DIR} | /usr/bin/sed -n -e "/^${BACKUP_DB}_full_${WEEK_OF_YEAR}/p" | /usr/bin/sed -n -e "/tar.gz$/!p")

# 해당 년주차에 풀백업이 없으면 풀백업 있으면 증분백업
if [ "${LAST_FULL_BACKUP_NM}" == "" ];then
  # full backup
  export BACKUP_TYPE="full"
else
  # incremental backup
  export BACKUP_TYPE="incremental"
  export LAST_FULL_BACKUP_PATH="${BASE_DIR}/${LAST_FULL_BACKUP_NM}"
fi

# 백업 생성될 디렉토리명
export TARGET_DIR="${BACKUP_DB}_${BACKUP_TYPE}_${WEEK_OF_YEAR}"

# 백업 파일명
export TARGET_NM="${TARGET_DIR}_${DATE_TIME}"

# 해당 백업의 상세 내역이 기록될 로그경로
export LOG_PATH="${BASE_DIR}/logs/${TARGET_NM}.log"

if [ ${BACKUP_TYPE} == "full" ]; then
  # 풀백업 생성될 경로
  export TARGET_PATH="${BASE_DIR}/${TARGET_DIR}"

  #### full backup ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start ${BACKUP_TYPE} backup ${TARGET_NM} to ${TARGET_DIR}"
  mariabackup --backup --user=mariabackup --password='root 계정 비밀번호' --no-lock --socket=/var/lib/mysql/mysql.sock --target-dir=${TARGET_PATH} >> $LOG_PATH 2>&1

  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] mariabckup fail, show ${LOG_PATH}"
      exit 9
  fi

  #### full backup prepareing ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start ${BACKUP_TYPE} backup prepareing to ${TARGET_NM}"
  mariabackup --prepare --no-lock --socket=/var/lib/mysql/mysql.sock --target-dir=${TARGET_PATH} >> $LOG_PATH 2>&1
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] mariabckup prepare fail, show ${LOG_PATH}"
      exit 9
  fi

  #### compress backup ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress Backup ${TARGET_DIR} to ${TARGET_NM}.tar.gz"
  /usr/bin/tar zcvf ${TARGET_PATH}.tar.gz -C${BASE_DIR} ${TARGET_DIR} >> $LOG_PATH 2>&1

  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress fail"
      exit 9
  fi

else
  # 증분백업 생성될 경로
  export TARGET_PATH="${BASE_DIR}/${TARGET_NM}"

  #### incremental backup ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start ${BACKUP_TYPE} backup ${TARGET_NM} for ${LAST_FULL_BACKUP_NM}"
  mariabackup --backup --user=mariabackup --password='root 계정 비밀번호' --no-lock --socket=/var/lib/mysql/mysql.sock --incremental-basedir=${LAST_FULL_BACKUP_PATH} --target-dir=${TARGET_PATH} >> $LOG_PATH 2>&1
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] mariabckup fail, show ${LOG_PATH}"
      exit 9 
  fi

  #### incremental prepareing ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start ${BACKUP_TYPE} prepareing ${TARGET_NM} to ${LAST_FULL_BACKUP_NM}"
  mariabackup --prepare --no-lock --socket=/var/lib/mysql/mysql.sock --target-dir=${LAST_FULL_BACKUP_PATH} --incremental-dir=${TARGET_PATH} >> $LOG_PATH 2>&1
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] mariabckup prepare fail, show ${LOG_PATH}"
      exit 9 
  fi

  #### compress incremental backup ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress incremental Backup ${TARGET_NM}.tar.gz"
  /usr/bin/tar zcvf ${TARGET_PATH}.tar.gz -C${BASE_DIR} ${TARGET_NM} >> $LOG_PATH 2>&1
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress fail"
      exit 9
  fi

  #### remove incremental backup directory ##########
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Remove incremental Backup directory ${BASE_DIR}/${TARGET_NM}"
  /usr/bin/rm -rf ${BASE_DIR}/${TARGET_NM}
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Remove fail"
      exit 9
  fi

  #### compress incremented full backup ##########
  # 증분백업이 합쳐진 풀백업 명
  export INCREMENTED_BACKUP_NM="${LAST_FULL_BACKUP_NM}_incremented_${DATE_TIME}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress incremented full Backup ${LAST_FULL_BACKUP_NM} to ${INCREMENTED_BACKUP_NM}.tar.gz"
  /usr/bin/tar zcvf ${BASE_DIR}/${INCREMENTED_BACKUP_NM}.tar.gz -C${BASE_DIR} ${LAST_FULL_BACKUP_NM} >> $LOG_PATH 2>&1
  if [ $? -ne 0 ];then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compress fail"
      exit 9
  fi

fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup Complate ${TARGET_NM}"
