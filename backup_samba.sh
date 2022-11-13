#!/bin/bash

# Для этого скрипта потребуются такие переменные:
BACKUP_LOCK=/var/lock/backup_vm.lock
BACKUP_LOG=/var/log/backup.log
USED_SPACE=95
BACKUP_DURATION=30

# Данные для подключения внешней шары:
REMOTE_BACKUP_DIR=FirstTestShare 
USER=backupsamba
PASSWORD="backup12"
REMOTE_HOST=192.168.88.33 

# Информация, нужная для самого резервного копирования:
BACKUP_DIR=/mnt/share
DT=`date '+%Y%m%d'`
BACKUP_SRC=/home/virt3/backups

# Функция для записи логов в красивом отформатированном виде:
function toLog {
local message=$1
echo "[`date \"+%F %T\"`] ${message}" >> $BACKUP_LOG
}

# Функция проверки свободного места. Если оно кончается, то эта информация попадет в лог-файл.
function checkUsedSpace {
if [[ `df -h|grep //$REMOTE_HOST/$REMOTE_BACKUP_DIR|awk '{print $5}'|sed 's/%//g'` -ge $USED_SPACE ]]; then
toLog "Used space on $REMOTE_HOST:$REMOTE_BACKUP_DIR higher then $USED_SPACE%."
toLog "END"
toLog ""
rm -f $BACKUP_LOCK
umount $BACKUP_DIR
exit
fi
}

# Функция для чистки папки бэкапов от старых файлов.
function checkBackupDir {
local BACKUP_DURATION=$1
find $BACKUP_DIR/$host/$backup_level -type f -mtime +$BACKUP_DURATION -exec rm -rf {} \;
}

# Проверяем, не запущен ли уже процесс бэкапа.
while [ -e $BACKUP_LOCK ]
do
sleep 1
done

touch $BACKUP_LOCK
toLog "START"

# Монтируем сетевую папку. Если не смонтировалась, то выходим с ошибкой
mount -t cifs //$REMOTE_HOST/$REMOTE_BACKUP_DIR $BACKUP_DIR -o username=$USER,password=$PASSWORD,rw > /dev/null 2>&1
if [ $? -ne 0 ]; then
if [[ `df -h|grep //$REMOTE_HOST/$REMOTE_BACKUP_DIR|awk '{print $1 $6}'` == "//$REMOTE_HOST/$REMOTE_BACKUP_DIR$BACKUP_DIR" ]]; then
checkUsedSpace
else
toLog "Problems with mounting directory"
toLog "END"
toLog ""
rm -f $BACKUP_LOCK
exit
fi
fi

# Пихаем данные в архив и складываем на сетевую шару:
tar cvfz $BACKUP_SRC/$DT.tar.gz $BACKUP_DIR

toLog "END"
toLog ""

rm -f $BACKUP_LOCK
umount $BACKUP_DIR
exit
