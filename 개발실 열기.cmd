@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo   SkillCraft 개발실을 켭니다...
echo.
where node >nul 2>nul
if errorlevel 1 (
  echo   [!] Node.js 가 없습니다. setup.ps1 을 먼저 실행하세요.
  echo       powershell -ExecutionPolicy Bypass -File setup.ps1
  echo.
  pause
  exit /b 1
)
start "" http://localhost:3100
node office\server\project-api.mjs
pause
