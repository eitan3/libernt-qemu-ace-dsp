@echo off
setlocal
set GUID=
for /f "delims=" %%k in ('reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render') do (
  echo %%k | findstr /c:"{" | findstr /c:"}" >nul && reg query "%%k\Properties" /v "{a45c254e-df1c-4efd-8020-67d146a850e0},14" 2>nul | findstr /i "Loopback" >nul && set GUID=%%~nk
)
set GUID=%GUID:~0,38%
echo GUID=%GUID% > %~d0\setdef.txt
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\%GUID%\Properties" >> %~d0\setdef.txt 2>&1
reg add HKCU\Software\Wine\Drivers\wdmaud.drv /v DefaultOutput /t REG_SZ /d "{0.0.0.00000000}.%GUID%" /f >> %~d0\setdef.txt 2>&1
reg query HKCU\Software\Wine\Drivers\wdmaud.drv /v DefaultOutput >> %~d0\setdef.txt 2>&1
