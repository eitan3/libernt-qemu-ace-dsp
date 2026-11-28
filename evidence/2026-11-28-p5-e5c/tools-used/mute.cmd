@echo off
cd /d %~d0\
endpointmute.exe %1 > %~d0\mute-%1.txt 2>&1
