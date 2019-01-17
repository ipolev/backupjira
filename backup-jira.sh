#!/bin/bash

JIRA_INSTALL="/opt/atlassian/jira/"
JIRA_HOME="/var/atlassian/application-data/jira/"
TIMESTAMP=`date '+%d%m%y_%H%M%S'`
JIRA_BACKUP_DIR="/srv/jira-backup-$TIMESTAMP"
PID_FILE="/var/run/atlassian-backup.pid"
LOG_FILE="/var/log/backup-jira_$TIMESTAMP.log"
DAYS=30

# Print messages to log file
_log() {
   echo "$(date '+%b %d %T') $1: $2" >> $LOG_FILE
}

# Creating backups
_create_backup() {
/etc/init.d/jira stop; #JIRA_STOP_STATUS=$?
sleep 10

if [ ! -f $JIRA_INSTALL/jira/work/catalina.pid ]; then
   MSG="JIRA services stopped successfully"
   _log INFO "$MSG"

   mkdir -p $JIRA_BACKUP_DIR/$JIRA_INSTALL
   if [ -d $JIRA_BACKUP_DIR/$JIRA_INSTALL ]; then
	MSG="Creating installation directory backups"
	_log INFO "$MSG"
	rsync -avhP $JIRA_INSTALL $JIRA_BACKUP_DIR/$JIRA_INSTALL; INSTALL_BACKUP_STATUS=$?
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

   mkdir -p $JIRA_BACKUP_DIR/$JIRA_HOME
   if [ -d $JIRA_BACKUP_DIR/$JIRA_HOME ]; then
	MSG="Creating home directory backups"
	_log INFO "$MSG"
	rsync -avhP $JIRA_HOME $JIRA_BACKUP_DIR/$JIRA_HOME; HOME_BACKUP_STATUS=$?
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

   if [ -d $JIRA_BACKUP_DIR ]; then
	MSG="Creating database backups"
	_log INFO "$MSG"
	pg_dump -U postgres jiradb > $JIRA_BACKUP_DIR/jiradb.sql; DB_BACKUP_STATUS=$?
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

   if [ $INSTALL_BACKUP_STATUS -eq 0 ] && [ $HOME_BACKUP_STATUS -eq 0 ] && [ $DB_BACKUP_STATUS -eq 0 ]; then
	MSG="Creating JIRA backups archive"
	_log INFO "$MSG"
	cd $JIRA_BACKUP_DIR
	tar czf jira-backup-$TIMESTAMP.tar.gz ./*; JIRA_BACKUP=$?
	if [ $JIRA_BACKUP -eq 0 ]; then
	   MSG="... Created"
	   _log INFO "$MSG"
	else
	   MSG="... Failed"
	   _log ERROR "$MSG"
	   exit 1
	fi
   else
	MSG="Some problem with INSTALL|HOME|DB JIRA backups ..."
	_log ERROR "$MSG"
	exit 1
   fi

else
   MSG="Failed to stop JIRA services"
   _log ERROR "$MSG"
   exit 1
fi

/etc/init.d/jira start; JIRA_START_STATUS=$?
sleep 10

if [ $JIRA_START_STATUS -eq 0 ] && [ -f /opt/atlassian/jira/work/catalina.pid ]; then
   MSG="JIRA services started successfully"
   _log INFO "$MSG"
else
   MSG="Failed to start JIRA services"
   _log ERROR "$MSG"
   exit 1
fi
}

if [ ! -f $PID_FILE ]; then
   echo $$ > $PID_FILE
   _create_backup
   rm -f $PID_FILE
   #find $JIRA_BACKUP_DIR/ -mtime +$DAYS -exec rm -f {} \;
else
   $MSG="Script is already started"
   echo "$MSG"
   _log ERROR "$MSG"
   exit 1
fi