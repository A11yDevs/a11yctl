@echo off
setlocal
chcp 65001 > nul
echo [ea11ctl] Aviso: ea11ctl esta obsoleto e sera removido em versao futura. Use a11yctl.
set "A11YCTL_CMD=%~dp0a11yctl.cmd"
call "%A11YCTL_CMD%" %*
exit /b %ERRORLEVEL%