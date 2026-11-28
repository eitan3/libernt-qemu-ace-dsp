@echo off
cd /d %~d0\
sc query Nwifi > %~d0\svc-nwifi.txt 2>&1
