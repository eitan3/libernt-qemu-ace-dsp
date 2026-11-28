@echo off
cd /d %~d0\
procinfo.exe %1 > %~d0\hc-%1.txt 2>&1
