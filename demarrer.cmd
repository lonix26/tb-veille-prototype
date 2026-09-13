@echo off
rem Demarrage du prototype sous Windows : delegue a demarrer.sh via Git Bash, sinon WSL.
setlocal
cd /d "%~dp0"
set MSYS_NO_PATHCONV=1
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if defined BASH (
  "%BASH%" demarrer.sh
  goto fin
)
where bash >nul 2>nul && (
  bash demarrer.sh
  goto fin
)
where wsl >nul 2>nul && (
  wsl bash demarrer.sh
  goto fin
)
echo Il faut Git pour Windows (https://git-scm.com) ou WSL pour lancer demarrer.sh.
echo Docker Desktop seul ne suffit pas : le script est ecrit pour bash.
:fin
echo.
pause
endlocal
