@echo off
cd /d %~d0\
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture" /s > %~d0\cap.txt 2>&1
