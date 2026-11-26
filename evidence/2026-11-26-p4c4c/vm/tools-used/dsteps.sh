#!/bin/bash
# dsteps.sh -- the by-eye steps of VM 4 of the p4c4c round that need a command's text (D12's
# format change read back from the registry) or a launch by a URI (D12's Settings page, D14's
# Microphone page): dsteps.sh <step>
#   fmt      close both Sound dialogs, a console, the render endpoint's Properties key read to the data disk
#   uri <name> <uri>   the Run dialog, the URI typed, a screenshot after 40 s
set -u
RUN="${RUN:-r4-byeye}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
SOCK=$(cat "$EV/sock-dir.txt")
case "$1" in
    fmt)
        g key esc >/dev/null; sleep 3; g key esc >/dev/null; sleep 3
        console
        cmd x-fmt-after.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Render\\{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}\\Properties" 40
        ;;
    uri)
        g key meta_l-r >/dev/null; sleep 4
        g key home shift-end >/dev/null; sleep 1
        g type "$3" >/dev/null; g key ret >/dev/null; sleep 40
        g shot "$2" >/dev/null
        log "step $2: the Run dialog, '$3', the screenshot $2.png"
        ;;
esac
exit 0
