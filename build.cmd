call build\install-lazarus
for /F %%F in ('dir /s /b src\*.lpr') do call build\bin\lazbuild.exe -B %%F
