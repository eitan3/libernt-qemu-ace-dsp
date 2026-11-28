@echo off
set LIBERNT_APITEST_REQUIRED=1
cd /d %~d0\
dsploop_apitest.exe > %~d0\dl-%1.txt 2>&1
