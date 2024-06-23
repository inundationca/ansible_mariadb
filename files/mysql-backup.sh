#!/usr/bin/env bash

# -------- MySQL Backup Script ---------

# Author: Inundation

# Description:
# This script is intended to be used as apart of a crontab job to perform periodic backups of MySQL databases.

# Version Information:
# v1.0.0 - Script creation.

# Usage:
# ./mysql-backup.sh
#
# Cronjob Entry:
# 0 20 * * * /opt/mysql-backup/mysql-backup.sh      # Run nightly at 10:00pm.

# Variables:
# TIMESTAMP          - Timestamp added to filename.
# BACKUPDIR          - Backup directory location. By default this will be a `backups` folder under the scripts working directory.
# DAYSTOKEEP         - The number of days to retain the backup files.

# ---------------------------------------

# -- Scripting Utilties --

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# Cleanup function.
# Executed when script error occurs.
cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    # Cleanup tasks.
}

# Logging function.
# Writes log information to STOUT and specified logfile.
function log {
  echo `date "+%Y/%m/%d %H:%M:%S"`" $1"
  echo `date "+%Y/%m/%d %H:%M:%S"`" $1" >> $LOGFILE
}

# -- Variables --

DAYSTOKEEP=14                            # Number of days to retain database backups.
TIMESTAMP=$(date +"%F")                 # Timestamp used when generating backup filename.
BACKUPDIR=$SCRIPTDIR/backups            # Location where backups are written too.
LOGFILE=/var/log/mysql-backup.log       # Location where log files will be written too.

# -- Dependences --

MYSQL="/usr/bin/mysql"                  # Location of mysql executable.
MYSQLDUMP="/usr/bin/mysqldump"          # Location of mysqldump executable.
BZIP2="/usr/bin/bzip2"                  # Location of bzip2 executable.

# -- Functions --

# Function to verify that required packages are installed.
ProgramInstalled () {
    if [ ! -f $1 ]; then
        log "$1 could not be found. Please install and re-run script. Exiting."
        exit;
    else
        log "Confirmed $i is installed."
    fi
}

# -- Prerequisites --

log "**** STARTING BACKUP PROCESS ****"

# Check and create backup directory if non-existent.

if [ ! -d $BACKUPDIR ]; then
    log "Creating backup directory."
    mkdir -p $BACKUPDIR
else
    log "Backup directory exists. Skipping creating directory."
fi

# Check and verify all dependencies are installed.

for i in $MYSQL $MYSQLDUMP $BZIP2; do
    ProgramInstalled "$i"
done

# Check if MySQL is running and credentials are valid.

if ! $MYSQL -e "status" > /dev/null 2>&1; then
    log "Connection attempt to MySQL failed. Check service and verify credentials. Exiting."; exit;
else
    log "Confirmed connectivity to MySQL process."
fi

# -- Backup Process --

log "Starting backup process."

# Collect a list of databases to backup.
DATABASELIST=`$MYSQL -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys)"`

# Perform backup routine on each database.
for DB in $DATABASELIST; do

    DBFILENAME=$BACKUPDIR/$DB.$TIMESTAMP.sql.bz2

    # Check if backup already exists.
    if [ ! -f $DBFILENAME ]; then
        mysqldump --databases --single-transaction $DB > $DBFILENAME || { log >&2 "Writing $DBFILENAME failed. Exiting."; exit; }
        log "Database backup of $DB successfully written to $DBFILENAME."
    else
        log "$DBFILENAME already exists"
    fi
done

# Delete backups older than $DAYSTOKEEP
EXPIREDBACKUPS=($(find $BACKUPDIR -name "*.sql.bz2" -type f -mtime +$DAYSTOKEEP))

if [ ${#EXPIREDBACKUPS[@]} -eq 0 ]; then
        log "No expired backups found."
else
        for i in ${EXPIREDBACKUPS[@]}; do
                log "Expired backup found. Deleting $i."
                rm $i
        done
fi