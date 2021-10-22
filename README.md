# bk.sh
Simple Backup script

# Help
```
Usage: bk.sh [S:R:d:r:galsxh]

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
        bk.sh FILEPATH

      List with search
        bk.sh -l FILEPATH (Regex pattern is working)

      List all files
        bk.sh -l

      Restore with search
        bk.sh -r ID (Id from list and search) FILEPATH

      Restore without search
        bk.sh -r ID (Id from list without search)

    Envars:
        BK_BACKUPDIR    < Set backup dir
        BK_MANIFESTDIR  < Set manifest dir
        BK_GZIP         < Gzip backup
```

# Todo
* implement comentary section in manifest
* implement checksum verification and size manifest to verify backup
* implement rsync as second option instead of cp
* set file on lock during backup
