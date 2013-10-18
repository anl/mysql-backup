#!/bin/bash

# If calling from cron, recommend running this script with timeout(1)

set -e

trap 'echo Exiting from error $? at line $LINENO; if [ ! -z "$dump_msgs" ] ; then echo $dump_msgs; fi' ERR

function usage {
    echo "Usage: $0 -d directory [-t]"
    echo "Usage: $0 -h"
    echo
    echo " -d <directory>  path to write backups to"
    echo " -t              append timestamp to backup filenames"
    exit 1
}

append_timestamp='false'
while getopts "d:ht" flag; do
    case $flag in
	d) backup_dir=$OPTARG ;;
	t) append_timestamp='true' ;;
	*) usage ;;
    esac
done

if [ -z "$backup_dir" ]; then
    echo "Backup directory must be specified."
    echo
    usage
fi

if [[ $append_timestamp == 'true' ]] ; then
    timestamp=$(date +-%Y%m%d%H%M%S)
else
    timestamp=''
fi

if [ ! -d $backup_dir ]; then
    mkdir -p $backup_dir
fi

for db in $(echo 'show databases' | mysql -Bs); do
    if [[ $db == 'information_schema' || $db == 'performance_schema' ]]; then
	continue
    fi
    logger "${0}: ${db}: backup started"
    # Capture stderr of mysqldump; stdout goes to file
    # Ref. http://stackoverflow.com/questions/3130375/bash-script-store-stderr-in-variable
    dump_msgs=$((mysqldump $db > ${backup_dir}/${db}${timestamp}.sql) 2>&1)
    if [ -n "$dump_msgs" ]; then
	old_ifs=$IFS
	# Make newline the internal field separator:
	IFS='
'
	for line in $dump_msgs; do
	    logger "${0}: ${db}: $line"
	done
	IFS=$old_ifs
    fi
    logger "${0}: ${db} backup completed"
done
