mnestic.lua

keep folders in tmpfs, sync to persist storage when processes are not using them

at start, copy persist to tmpfs. checks for running processes every 60s with
pgrep. copies tmpfs to persist when associated process exits

no support provided. may cause data loss

install:
    - luarocks install subproc luaposix
    - ensure commands: rsync, pgrep, ln, date

configure:
    - edit mnestic.lua
    - set ramfs_root = directory in tmpfs
    - set mnestic_root = presistent storage
    - set targets =
        array of
            {
                process = name of process associated with dirs. dirs will sync
                after process exits

                directories = list of directories to sync. use `home .. "path"`
                for $HOME/path
            }

run:
    - run mnestic.lua as user or root


todo:
    - if user initiate system shutdown before sync finishes, data loss will
      occur. want a way to let shutdown wait for sync end
