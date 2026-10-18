@echo off
setlocal
title Fear ^& Hunger - Patcher Catala
cd /d "%~dp0"

echo.
echo  =================================================
echo    Fear ^& Hunger  -  PARCHE EN CATALA
echo    Fear ^& Hunger  -  PATXE AL CATALA
echo  =================================================
echo.

if not exist "%~dp0tools\fyh.ps1" (
  echo  [ERROR] Falta la carpeta tools\ del paquete. No muevas los archivos.
  echo  [ERROR] Falta la carpeta tools\ del paquet.
  pause
  exit /b 1
)
if not exist "%~dp0files\data\System.json" (
  echo  [ERROR] Falta la carpeta files\ del paquete. Vuelve a descomprimir el zip.
  echo  [ERROR] Falta la carpeta files\ del paquet.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\fyh.ps1" -Mode patch -Root "%~dp0"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" (
  echo  Operacion terminada correctamente. / Operacio acabada correctament.
) else (
  echo  Proceso terminado con codigo %EC% / Process acabat amb codi %EC%.
)
echo.
pause
exit /b %EC%
