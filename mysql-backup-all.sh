#!/bin/bash

# If calling from cron, recommend running this script with timeout(1)

set -e

function usage {
    echo "Usage: $0 -d directory"
    echo "Usage: $0 -h"
    echo
    echo " -d directory to write backups to"
    exit 1
}

while getopts "d:h" flag; do
    case $flag in
	d) backup_dir=$OPTARG ;;
	*) usage ;;
    esac
done

if [ -z "$backup_dir" ]; then
    echo "Backup directory must be specified."
    echo
    usage
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
    dump_msgs=$((mysqldump $db > ${backup_dir}/${db}.sql) 2>&1)
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
