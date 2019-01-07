#!/bin/bash

TIMESTAMP=`date '+%d%m%y_%H%M%S'`
INSTALL_BACKUP="/srv/backup/atlassian_install_backup_$TIMESTAMP"
HOME_BACKUP="/srv/backup/atlassian_home_backup_$TIMESTAMP"
DATABASE_BACKUP="/srv/backup/atlassian_db_backup_$TIMESTAMP"
BACKUP_LOG_FILE="atlassian_backup_${TIMESTAMP}.log"
PID_FILE="/var/run/atlassian-backup.pid"
LOG_FILE="./backup-jira.log"

# Print messages to log file
_log() {
   echo "$(date '+%b %d %T') $1: $2" >> $LOG_FILE
}

# Creating backups
_create_backup() {
/etc/init.d/jira stop; JIRA_STOP_STATUS=$?
sleep 10

if [ $JIRA_STOP_STATUS -eq 0 ]; then
   MSG="Atlassian services stopped successfully"
   _log INFO "$MSG"

   mkdir -p $INSTALL_BACKUP
   if [ -d $INSTALL_BACKUP ]; then
	MSG="Creating installation directory backups"
	_log INFO "$MSG"
	rsync -avhP /opt/atlassian/ $INSTALL_BACKUP; INSTALL_BACKUP_STATUS=$?
	if [ $INSTALL_BACKUP_STATUS -eq 0 ]; then
	   MSG="... Created"
	   _log INFO "$MSG"
	else
	   MSG="... Failed"
	   _log ERROR "$MSG"
	   exit 1
	fi
   else
   MSG="Installation backup directory doesn't exist"
   _log ERROR "$MSG"
   exit 1
   fi

   mkdir -p $HOME_BACKUP
   if [ -d $HOME_BACKUP ]; then
	MSG="Creating home directory backups"
	_log INFO "$MSG"
	rsync -avhP /var/atlassian/application-data/ $HOME_BACKUP; HOME_BACKUP_STATUS=$?
	if [ $HOME_BACKUP_STATUS -eq 0 ]; then
	   MSG="... Created"
	   _log INFO "$MSG"
	else
	   MSG="... Failed"
	   _log ERROR "$MSG"
	   exit 1
	fi
   else
	MSG="Home backup directory doesn't exist"
	_log ERROR "$MSG"
	exit 1
   fi

   mkdir -p $DATABASE_BACKUP
   if [ -d $DATABASE_BACKUP ]; then
	MSG="Creating database backups"
	_log INFO "$MSG"
	pg_dump -U postgres jiradb > $DATABASE_BACKUP/jiradb.sql; DB_BACKUP_STATUS=$?
	if [ $DB_BACKUP_STATUS -eq 0 ]; then
	   MSG="... Created"
	   _log INFO "$MSG"
	else
	   MSG="... Failed"
	   _log ERROR "$MSG"
	   exit 1
	fi
   else
	MSG="Database backup directory doesn't exist"
	_log ERROR "$MSG"
	exit 1
   fi
else
   MSG="Failed to stop atlassian services"
   _log ERROR "$MSG"
   exit 1
fi

/etc/init.d/jira start; JIRA_START_STATUS=$?
sleep 10
if [ $JIRA_START_STATUS -eq 0 ]; then
   MSG="Atlassian services started successfully"
   _log INFO "$MSG"
else
   MSG="Failed to start atlassian services"
   _log ERROR "$MSG"
   exit 1
fi
}

if [ ! -f $PID_FILE ]; then
   echo $$ > $PID_FILE
   _create_backup
   rm -f $PID_FILE
else
   $MSG="Script is already started"
   echo "$MSG"
   _log ERROR "$MSG"
   exit 1
fi