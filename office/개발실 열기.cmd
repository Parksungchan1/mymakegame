@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo   SkillCraft 개발실을 켭니다...
echo.
where node >nul 2>nul
if errorlevel 1 (
  echo   [!] Node.js 가 설치되어 있지 않습니다.
  echo       https://nodejs.org 에서 LTS 버전을 설치한 뒤 다시 실행하세요.
  echo.
  pause
  exit /b 1
)
start "" http://localhost:3100
node server/project-api.mjs
pause
