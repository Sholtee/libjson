::
:: build.cmd
::
:: Author: Denes Solti
::
@echo off

@echo installing Lazarus:
call build\install-lazarus
echo:

@echo starting build:
for /F %%F in ('dir /s /b src\*.lpr tests\*.lpr') do (
  @echo: 
  @echo build file: %%F 
  call build\bin\lazbuild.exe -B %%F
)