
err() {
    echo $* >&2
}

usage() {
    err "$(basename $0): [init|zip|upload|dump|dump<db_type><install>]|dump<db_type>"
}

init() {
    echo "  _  __     _        _   _                              "
    echo " | |/ /   _| | ___  | \ | | __ _ _   _ _   _  ___ _ __  "
    echo " | ' / | | | |/ _ \ |  \| |/ _\` | | | | | | |/ _ \ '_ \ "
    echo " | . \ |_| | |  __/ | |\  | (_| | |_| | |_| |  __/ | | |"
    echo " |_|\_\__, |_|\___| |_| \_|\__, |\__,_|\__, |\___|_| |_|"
    echo "      |___/                |___/       |___/            "
    echo "author: https://github.com/truonghdpk"
    apt update
    apt install wget
    wget https://github.com/prasmussen/gdrive/releases/download/2.1.1/gdrive_2.1.1_linux_386.tar.gz
    tar -xvf gdrive_2.1.1_linux_386.tar.gz
    ./gdrive about
}

zip() {
    zip -r backup.zip
}

drive() {
    ./gdrive
}

# drive-logout() {
#     rm -rf ~/.gdrive
# }


dumphelp() {
    echo '🐳🐳🐳 INSTRUCTIONS TO DUMP DATABASE FAMILY 🐳🐳🐳'
    echo 'Mongo:'
    echo '              export SERVER=localhost:27017'
    echo '              export DATABASE=<db>'
    echo ''
    echo 'Postgres:'
    echo '              export HOSTNAME=localhost'
    echo '              export USERNAME=postgres'
    echo '              export PASSWORD='
    echo '              export DATABASE=postgres'
    echo ''
    echo 'Elasticsearch:'
    echo '              export HOSTNAME=http://localhost:9200'
    echo '              export BACKUP_INDEX=my-index'
    echo ''
    echo 'MINIO:'
    echo '              export BUCKET_NAME=my-bucket'
    echo '----------------------------------------'
    echo '🛠🛠🛠 INSTRUCTIONS TO LOAD DUMP DATABASE FAMILY 🛠🛠🛠'
    echo ''
    echo 'Mongo:'
    echo '              export SERVER=localhost:27017'
    echo '              export DATABASE=<db>'
    echo '              export FILENAME=<file>'
    echo ''
    echo 'Postgres:'
    echo '              export HOSTNAME=localhost'
    echo '              export USERNAME=postgres'
    echo '              export PASSWORD='
    echo '              export DATABASE=postgres'
    echo '              export FILENAME_GZIP=<file>'
    echo ''
    echo 'Elasticsearch:'
    echo '              export HOSTNAME=http://localhost:9200'
    echo '              export BACKUP_INDEX=my-index'
    echo 'MINIO:'
    echo '              export BUCKET_NAME=my-bucket'
}
# DUMP INSTALL
dumpmongoinstall() {
    apt install mongo-tools
}
dumppostgresinstall() {
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt install postgresql-client-13
    apt install postgresql-client-14
}
dumpelasticsearchinstall() {
    apt install jq
}
dumpelasticsearch() {
    base_dir="$(dirname "$0")"

    URL=$HOSTNAME
    REPO=$BACKUP_INDEX
    # Number of snapshots to keep
    LIMIT=30
    # For test
    #LIMIT=3
    # Snapshot naming convention
    SNAPSHOT=`date +%Y%m%d-%H%M%S`

    #!/bin/bash

    base_dir="$(dirname "$0")"
    source $base_dir/shell-variables

    curl -XPUT "$URL/_snapshot/$REPO/$SNAPSHOT?wait_for_completion=true" | jq '.'
}
# DUMP BACKUP
dumppostgres() {
    echo '=========================================================='
    echo 'ALL CHECK BACKUP PARAMS:'
    echo "export HOSTNAME=$HOSTNAME"
    echo "export USERNAME=$USERNAME"
    echo "export PASSWORD=$PASSWORD"
    echo "export DATABASE=$DATABASE"
    echo '=========================================================='

    FILENAME=postgres_dump_$(date +%Y-%m-%d).backup
    echo "Pulling Database: This may take a few minutes"
    export PGPASSWORD=$PASSWORD
    pg_dump -a -Fc -h $HOSTNAME -U $USERNAME $DATABASE > $FILENAME
    unset PGPASSWORD
    gzip $FILENAME
    echo '=========================================================='
    echo 'LOAD DUMP DATABASE WITH COMMAND:'
    echo "export HOSTNAME=$HOSTNAME"
    echo "export USERNAME=$USERNAME"
    echo "export PASSWORD=$PASSWORD"
    echo "export DATABASE=$DATABASE"
    echo "export FILENAME_GZIP=$FILENAME.gz"
    echo '=========================================================='

}

dumpmongo() {
    FILENAME=mongo_backup_`date +%m%d%y%H`.zip
    DEST=./$FILENAME
    mongodump -h $SERVER -d $DATABASE --archive=$DEST --gzip
}
dumpminio() {
    FOLDERNAME=minio_backup_$(date +%Y-%m-%d)
    mkdir -p $FOLDERNAME
    mc mirror -w $FOLDERNAME play/$BUCKET_NAME
}

# LOAD DUMP
loaddumppostgres() {
    # Print config
    echo "----------------------------------------"
    echo "LOAD CONFIG:"
    echo "HOSTNAME: $HOSTNAME"
    echo "USERNAME: $USERNAME"
    echo "PASSWORD: $PASSWORD"
    echo "DATABASE: $DATABASE"
    echo "FILENAME_GZIP: $FILENAME_GZIP"
    echo "----------------------------------------"
    # Load dump
    gunzip $FILENAME_GZIP
    export FILENAME=$(basename $FILENAME_GZIP .gz)
    echo "File name: $FILENAME"
    echo "Pulling Database: This may take a few minutes"
    export PGPASSWORD=$PASSWORD
    pg_restore -a -Fc -h $HOSTNAME -d $DATABASE $FILENAME -U $USERNAME --disable-triggers --data-only --ignore-errors
    unset PGPASSWORD
}
loaddumpmongo() {
    mongorestore --gzip --host $SERVER --archive=$FILENAME --db $DATABASE --drop
}
loaddumpelasticsearch() {
    base_dir="$(dirname "$0")"
    URL=$HOSTNAME
    REPO=$BACKUP_INDEX
    # Number of snapshots to keep
    LIMIT=30
    # For test
    #LIMIT=3
    # Snapshot naming convention
    SNAPSHOT=`date +%Y%m%d-%H%M%S`
    # # ROTATION
    #!/bin/bash
    #
    # Clean up script for old elasticsearch snapshots.
    # 23/2/2014 karel@narfum.eu

    # Get a list of snapshots that we want to delete
    echo "curl -s -XGET \"$URL/_snapshot/$REPO/_all\" | jq -r \".snapshots[:-${LIMIT}][].snapshot\""
    SNAPSHOTS=`curl -s -XGET "$URL/_snapshot/$REPO/_all" | jq -r ".snapshots[:-${LIMIT}][].snapshot"`

    echo Snapshot List:
    echo $SNAPSHOTS

    # Loop over the results and delete each snapshot
    for SNAPSHOT in $SNAPSHOTS
    do
    echo "Deleting snapshot: $SNAPSHOT"
    curl -s -XDELETE "$URL/_snapshot/$REPO/$SNAPSHOT?pretty" | jq '.'
    if [ "$?" != "0" ]; then
        echo Could not delete $SNAPSHOT.
    fi
    done
    echo "Done!"

}
execute() {
    local task=${1}
    case ${task} in
        dumpmongoinstall)
            dumpmongoinstall
            ;;
        dumpmongo)
            dumpmongo
            ;;
        loaddumpmongo)
            loaddumpmongo
            ;;
        dumppostgresinstall)
            dumppostgresinstall
            ;;
        dumppostgres)
            dumppostgres
            ;;
        loaddumppostgres)
            loaddumppostgres
            ;;
        dumpelasticsearchinstall)
            dumpelasticsearchinstall
            ;;
        dumpelasticsearch)
            dumpelasticsearch
            ;;
        dump)
            dumphelp
            ;;
        init)
            init
            ;;
        zip)
            zip
            ;;
        drive)
            drive
            ;;
        drive-logout)
            drive-logout
            ;;
        all)
            init
            ;;
        *)
            err "invalid task: ${task}"
            usage
            exit 1
            ;;
    esac
}

main() {
    [ $# -ne 1 ] && { usage; exit 1; }
    local task=${1}
    execute ${task}
}

main $@
