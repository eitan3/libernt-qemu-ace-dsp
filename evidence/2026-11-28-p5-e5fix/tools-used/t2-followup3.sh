#!/bin/bash
# T2 follow-up 3: telnetd's CD inclusion; are the Nwifi / Packet lines upstream's? Read-only.
set -u
cd <home>/Projects/LiberNT || exit 1
echo "=== telnetd CMakeLists"
cat base/services/telnetd/CMakeLists.txt
echo
echo "=== telnetd in any image manifest"
git grep -n -i -F 'telnetd' -- image/ | head -5
echo
echo "=== Nwifi / Packet lines at upstream master bb96c5e4abf"
git grep -n -F -e 'Services\Nwifi","ImagePath' -e 'Services\Packet","ImagePath' bb96c5e4abf -- image/data/hivesys.inf
echo "(exit $?)"
echo "=== Nwifi / Packet lines at HEAD"
git grep -n -F -e 'Services\Nwifi","ImagePath' -e 'Services\Packet","ImagePath' HEAD -- image/data/hivesys.inf
echo "=== wifi.sys at upstream master (any file)"
git grep -n -F 'wifi.sys' bb96c5e4abf -- image/ drivers/network/ | head -5
