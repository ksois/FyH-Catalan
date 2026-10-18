@echo off
setlocal
title Fear ^& Hunger - Restaurar original
cd /d "%~dp0"

echo.
echo  =================================================
echo    Fear ^& Hunger  -  RESTAURAR ORIGINAL (ESPANOL)
echo    Fear ^& Hunger  -  RESTAURAR ORIGINAL (CASTELLA)
echo  =================================================
echo.

if not exist "%~dp0tools\fyh.ps1" (
  echo  [ERROR] Falta la carpeta tools\ del paquete. No muevas los archivos.
  echo  [ERROR] Falta la carpeta tools\ del paquet.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\fyh.ps1" -Mode unpatch -Root "%~dp0"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" (
  echo  Operacion terminada. / Operacio acabada.
) else (
  echo  Proceso terminado con codigo %EC% / Process acabat amb codi %EC%.
)
echo.
pause
exit /b %EC%
