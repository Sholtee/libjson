@echo off

@echo extracting files...
powershell.exe -nologo -noprofile -command "& { Add-Type -A  'System.IO', 'System.IO.Compression.FileSystem'; if (![IO.Directory]::Exists('bin')) {[IO.Compression.ZipFile]::ExtractToDirectory('lazarus-win32.zip', 'bin');} }"

@echo update config...
set bin=%cd%\bin

@echo --primary-config-path=%bin%\config>bin\lazarus.cfg

set xml=bin\environmentoptions.xml

@echo ^<?xml version="1.0"?^>>%xml%
@echo ^<CONFIG^>>>%xml%
@echo ^<EnvironmentOptions^>>>%xml%
@echo ^<Version Value="110" Lazarus="2.0.2"/^>>>%xml%
@echo ^<LazarusDirectory Value="%bin%"^>>>%xml%
@echo ^</LazarusDirectory^>>>%xml%
@echo ^<CompilerFilename Value="%bin%\fpc\3.0.4\bin\i386-win32\fpc.exe"^>>>%xml%
@echo ^</CompilerFilename^>>>%xml%
@echo ^<FPCSourceDirectory Value="%bin%\fpc\3.0.4\source"^>>>%xml%
@echo ^</FPCSourceDirectory^>>>%xml%
@echo ^<MakeFilename Value="%bin%\fpc\3.0.4\bin\i386-win32\make.exe"^>>>%xml%
@echo ^</MakeFilename^>>>%xml%
@echo ^<TestBuildDirectory Value="C:\Temp\"^>>>%xml%
@echo ^</TestBuildDirectory^>>>%xml%
@echo ^<Debugger Class="TGDBMIDebugger"/^>>>%xml%
@echo ^</EnvironmentOptions^>>>%xml%
@echo ^</CONFIG^>>>%xml%