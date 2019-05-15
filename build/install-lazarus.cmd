::
:: install-lazarus.cmd
::
:: Author: Denes Solti
::
@echo off

set zip=%~dp0lazarus-win32.zip

@echo checking integrity:
powershell -command "(get-filehash -algorithm md5 '%zip%').Hash"

set bin=%~dp0bin

@echo extracting files...
powershell.exe -nologo -noprofile -command "& { Add-Type -A  'System.IO', 'System.IO.Compression.FileSystem'; if (![IO.Directory]::Exists('%bin%')) {[IO.Compression.ZipFile]::ExtractToDirectory('%zip%', '%bin%');} }"
if %errorlevel% neq 0 exit /b %errorlevel%

@echo update config...
@echo --primary-config-path=%bin%>%bin%\lazarus.cfg

set fpc=%bin%\fpc\3.0.4
set fpcbin=%fpc%\bin\i386-win32

call "%fpcbin%\fpcmkcfg.exe" -d basepath="%fpc%" -o "%fpcbin%\fpc.cfg"
if %errorlevel% neq 0 exit /b %errorlevel%

set xml=%bin%\environmentoptions.xml

@echo ^<?xml version="1.0"?^>>%xml%
@echo ^<CONFIG^>>>%xml%
@echo ^<EnvironmentOptions^>>>%xml%
@echo ^<Version Value="110" Lazarus="2.0.2"/^>>>%xml%
@echo ^<LazarusDirectory Value="%bin%"^>>>%xml%
@echo ^</LazarusDirectory^>>>%xml%
@echo ^<CompilerFilename Value="%fpcbin%\fpc.exe"^>>>%xml%
@echo ^</CompilerFilename^>>>%xml%
@echo ^<FPCSourceDirectory Value="%fpc%\source"^>>>%xml%
@echo ^</FPCSourceDirectory^>>>%xml%
@echo ^<MakeFilename Value="%fpcbin%\make.exe"^>>>%xml%
@echo ^</MakeFilename^>>>%xml%
@echo ^<TestBuildDirectory Value="C:\Temp\"^>>>%xml%
@echo ^</TestBuildDirectory^>>>%xml%
@echo ^<Debugger Class="TGDBMIDebugger"/^>>>%xml%
@echo ^</EnvironmentOptions^>>>%xml%
@echo ^</CONFIG^>>>%xml%