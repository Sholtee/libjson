::
:: build.cmd
::
:: Author: Denes Solti
::
@echo off

@echo installing Lazarus:
call build\install-lazarus
if %errorlevel% neq 0 exit /b %errorlevel%
echo:

@echo starting build:
setlocal enabledelayedexpansion
for /F %%F in ('dir /s /b src\*.lpr tests\*.lpr') do (
  @echo: 
  @echo build file: %%F 
  call build\bin\lazbuild.exe -B %%F
  if !errorlevel! neq 0 exit /b !errorlevel!
)