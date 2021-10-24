#!/usr/bin/env lua

-- antimemetic folders, with periodic mnestics
-- require
--      luarocks: subproc, luaposix
--      commands: rsync, ln, date, pgrep

local subproc = require('subproc')
local posix = require('posix')

-- en

local home = os.getenv("HOME")
if home == nil then
    print "Error: no home directory set."
    os.exit(1)
end

-- ramfs
local ramfs_root = "/ram/mnestic"

-- persistent storage
local mnestic_root = home .. '/.mnestic'


local targets = {
    {
        process = "chromium",
        directories = {
            home .. "/.config/chromium",
            home .. "/.cache/chromium"
        }
    },
    {
        process = "palemoon",
        directories = {
            home .. "/.moonchild productions/pale moon",
            home .. "/.cache/moonchild productions/pale moon"
        }
    }
}

-- ensure no dir ends in slash
local dir_names = {ramfs_root, mnestic_root}
for _, target in ipairs(targets) do
    for _, dir in ipairs(target.directories) do
        table.insert(dir_names, dir)
    end
end
for _, dir in ipairs(dir_names) do
    local err = false
    if dir:sub(-1) == '/' then
        print("Error: directory '" .. dir .. "' ends with slash but should not")
        err = true
    end
    if err then
        os.exit(4)
    end
end


-- rsync, but do it right
--  - ensure trailing slash on src and dst
--  - rsync -a
local function correct_rsync(src, dst)
    if src:sub(-1) ~= '/' then
        src = src .. '/'
    end
    if dst:sub(-1) ~= '/' then
        dst = dst .. '/'
    end
    return subproc('rsync', '-a', src, dst)
end



print "Launching mnestic daemon"

print "Creating missing targets directories"
for _, target in ipairs(targets) do
    for _, dir in ipairs(target.directories) do
        subproc('mkdir', '-p', mnestic_root .. dir)
    end
end

print "Creating missing symlinks. Does not check that existing symlinks point to the right place"
for _, target in ipairs(targets) do
    for _, dir in ipairs(target.directories) do
        local _, _, exists = subproc('[', '-e', dir, ']')
        local _, _, is_symlink = subproc('[', '-L', dir, ']')
        if exists == 0 and is_symlink ~= 0 then
            print("Error: '" .. dir .. "' exists but is not a symlink")
            os.exit(3)
        end
        if is_symlink ~= 0 then
            local output, _, success = subproc('ln', '-s', ramfs_root .. dir, dir)
            if success ~= 0 then
                print("Error creating symlink for '" .. dir .. "': ")
                print(output)
                os.exit(2)
            end
        end
    end
end

print "Copying persistent storage to ramfs"
correct_rsync(mnestic_root, ramfs_root)

-- when process is not running, sync to persist
local function checkpoint()
    local date_printed = false
    for _, target in ipairs(targets) do
        local _, _, pgrep_code = subproc('pgrep', target.process)

        local running = pgrep_code == 0

        if running ~= target.was_running then
            if not running then
                if not date_printed then
                    local date = subproc('date')
                    print("")
                    print("------------------------")
                    print(date)
                    date_printed = true
                end
                for _, dir in ipairs(target.directories) do
                    print("Syncing " .. dir)
                    correct_rsync(ramfs_root .. dir, mnestic_root .. dir)
                end
            end
        end

        target.was_running = running
    end
    if date_printed then
        print("Sync done")
    end
end

print "Entering persistence loop"
local function main_loop()
    while true do
        checkpoint()
        posix.sleep(60)
    end
end

pcall(main_loop)
