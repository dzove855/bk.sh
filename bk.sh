#!/bin/bash

# XXX: implement comentary section in manifest 
# XXX: implement checksum verification and size manifest to verify backup
# XXX: implement rsync as second option instead of cp
# XXX: set file on lock during backup

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="S:R:d:r:galsxh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -g    Gzip
        -r    Restore ID
        -R    Remove ID
        -d    Backup directory
        -l    List
        -a    List show all info
        -S    View file content ID
        -h    Help
        -s    Dry-run
        -x    Xtrace

    Example
      Backup
        $SELF FILEPATH

      List with search
        $SELF -l FILEPATH (Regex pattern is working)

      List all files
        $SELF -l

      Restore with search
        $SELF -r ID (Id from list and search) FILEPATH

      Restore without search
        $SELF -r ID (Id from list without search)

    Envars:
        BK_BACKUPDIR    < Set backup dir
        BK_MANIFESTDIR  < Set manifest dir
        BK_GZIP         < Gzip backup 
"

shopt -s nullglob
shopt -s extglob

_quit(){
    local retCode="$1" msg="${@:2}"

    printf '%s \n' "$msg"
    exit "$retCode"
}

getFilesId(){
    local search="${1//\//|}"

    [[ $id =~ ^[0-9]+$ ]] || _quit 2 "Id is not a number"
    id=$(( id - 1 ))

    [[ -z "$search" ]] || search="*$search"

    for file in "$BK_BACKUPDIR/"$search*; do [[ "$file" =~ manifest && -d "$file" ]] && continue; files+=($file) ; done

    [[ -z "${files[id]}" ]] && _quit 2 "File does not exist"
}

list(){
    local search="${1//\//|}"
    local searchPattern
    local counter=1

    [[ -z "$search" ]] || search="*$search"

    if [[ -z "$showAll" ]]; then
        printf '%s %s %s %s\n\n\n' "ID" "FILE" "TIME" "VERSION"
    else
        printf '%s %s %s %s %s %s %s %s\n\n\n' "ID" "FILE" "TIME" "VERSION" "CHMOD" "UID" "GID" "GZIP" 
    fi
      
    for file in "$BK_BACKUPDIR/"$search*; do
        [[ "$file" =~ manifest && -d "$file" ]] && continue
        file="${file%.gz}"
        IFS='#' read path timestamp version <<<"${file//$BK_BACKUPDIR\//}"

        if [[ -z "$showAll" ]]; then
            printf '%d %s %d %s\n' "$counter" "${path//|//}" "$timestamp" "${version}"
        else
            read _ chmod uid gid gzip <"$BK_MANIFESTDIR/${file//$BK_BACKUPDIR\//}"
            [[ -z "$gzip" ]] && gzip=0 || gzip=1
            printf '%d %s %d %s %s %s %s %s\n' "$counter" "${path//|//}" "$timestamp" "${version}" "$chmod" "$uid" "$gid" "$gzip"
        fi
        ((counter++))
    done
}

restore(){
    local restoreFilePath

    getFilesId "$1"

    file="${files[id]%.gz}"
    read _ chmod uid gid gzip <"$BK_MANIFESTDIR/${file//$BK_BACKUPDIR\//}"
    [[ -z $gzip ]] || $_run gunzip "${files[id]}"
    IFS="#" read path timestamp version <<<"${files[id]//$BK_BACKUPDIR\//}"
    restoreFilePath="${path//|//}"
    $_run cp "$file" "$restoreFilePath"
    $_run chmod "$chmod" "$restoreFilePath"
    $_run chown "$uid" "$restoreFilePath"
    $_run chgrp "$gid" "$restoreFilePath"
    [[ -z $gzip ]] || $_run gzip "$file"
}

backup(){
    local file="$( realpath $1 )"
    local timestamp
    local files
    local version=1
    printf -v timestamp '%(%Y%m%d)T' -1
    
    files=("$BK_BACKUPDIR"/"${file//\//|}#${timestamp}#"*)
    [[ -z "${files[@]}" ]] || { 
        IFS='#' read path timestamp version <<<"${files[-1]%.gz}"
        (( version=version + 1 ))
    }


    if [[ -f "$file" ]]; then 
        $_run cp "$file" "$BK_BACKUPDIR"/"${file//\//|}#${timestamp}#${version}"
        $_run printf '%s %s %s %s' $(stat -c '%t %a %u %g' "$file") > "$BK_MANIFESTDIR"/"${file//\//|}#${timestamp}#${version}"
        if (( BK_GZIP )); then
            $_run gzip "$BK_BACKUPDIR"/"${file//\//|}#${timestamp}#${version}"  
            printf ' %s' "gzip" >> "$BK_MANIFESTDIR"/"${file//\//|}#${timestamp}#${version}"
        fi
    fi

}

remove(){
    getFilesId "$1"

    $_run rm "$BK_MANIFESTDIR/${files[id]//$BK_BACKUPDIR\//}"
    $_run rm "${files[id]}"
}

show(){
    getFilesId "$1"

    $_run ${PAGER:-less} "${files[id]}"
}

BK_BACKUPDIR="$HOME/var/backup/$SELF/${HOSTNAME%%.*}"

mode="backup"

type -p realpath &>/dev/null || _quit 2 "realpath does no exist"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        l) mode="list"                                                ;;
        a) mode="list"; showAll=1                                     ;;
        r) mode="restore"; id="${OPTARG}"                             ;;
        R) mode="remove"; id="${OPTARG}"                              ;;
        S) mode="show"; id="${OPTARG}"                                ;;
        g) BK_GZIP=1                                                  ;;
        d) BK_BACKUPDIR="${OPTARG%/}"                                 ;;
        s) _run="echo"                                                ;;
        x) set -x                                                     ;;
        h) _quit 0 "$HELP"                                            ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                         ;;
        *) _quit 1 "$USAGE"                                           ;;
    esac
done
shift $((OPTIND - 1))
BK_MANIFESTDIR="$BK_BACKUPDIR/manifest"

option="$1"

[[ -d "$BK_BACKUPDIR" ]] || mkdir -p "$BK_BACKUPDIR"
[[ -d "$BK_MANIFESTDIR" ]] || mkdir -p "$BK_MANIFESTDIR"

case "$mode" in 
    backup)
        if [[ -d "$option" ]]; then
            for file in "$option"/*; do
                $mode "$file"
            done
        else
            $mode "$option"
        fi
        ;;
    *) $mode "$option"
        ;;
esac
