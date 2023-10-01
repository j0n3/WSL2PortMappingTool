@echo off
setlocal enabledelayedexpansion
set "ruleNamePattern=Allowing LAN connections to port"

:: Check for administrative permissions
call :checkAdmin


:menu
cls
set "option="
echo.
echo Firewall Rules and Port Forwardings for WSL2
echo --------------------------------------------------
set "hasRules=0"
call :displayRules

echo.
echo 1) Create new rule and port forwarding
if "%hasRules%"=="1" echo 2) Delete an existing rule
echo 3) Exit
echo.
set /p option="Choose an option: "
goto option-%option% 2>nul
goto menu


:option-1
    call :createRule
    goto menu


:option-2
    call :deleteRule
    goto menu


:option-3
    exit


:checkAdmin
:: Check for administrative permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    call :requestAdmin
) else ( 
    call :gotAdmin 
)
exit /b


:requestAdmin
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"=""
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit

:gotAdmin
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
pushd "%CD%"
CD /D "%~dp0"
exit /b


:displayRules
:: Paso 1: Crear una lista de todos los puertos de las reglas de firewall que hemos creado
set "portsList="
for /f "tokens=*" %%l in ('netsh advfirewall firewall show rule name^=all ^| find "%ruleNamePattern%"') do (
    for %%p in (%%l) do set "portNum=%%p"
    if not "!portNum!"=="" set "portsList=!portsList! !portNum!"
    set "hasRules=1"
)

:: Paso 2: Para cada puerto en esa lista, extraer todos los forwardings asociados
for %%p in (%portsList%) do (
    if not "%%p"=="" (
        echo Firewall Rule: %ruleNamePattern% %%p
        for /f "tokens=1,2,3,4" %%a in ('netsh interface portproxy show all ^| findstr /C:"%%p"') do (
            echo       %%a:%%b to %%c:%%d
        )
        echo.
    )
)
exit /b


:ruleExists
setlocal
set "rulePort=%~1"
set "ruleExists=0"
for /f "tokens=*" %%a in ('netsh advfirewall firewall show rule name^=all ^| find "%ruleNamePattern% %rulePort%"') do (
    set "ruleExists=1"
)
endlocal & set "ruleExists=%ruleExists%"
exit /b


:createRule
set defaultLocalPort=5000
set defaultWslPort=5000
set defaultListenAddress=0.0.0.0

:: Reset user input values
set "localPort="
set "wslPort="
set "listenAddress="

call :getUserInput "Enter the local port (default: %defaultLocalPort%): " localPort %defaultLocalPort%
call :getUserInput "Enter the WSL2 port (default: %defaultWslPort%): " wslPort %defaultWslPort%
call :getUserInput "Enter a valid listenAddress (default: %defaultListenAddress%): " listenAddress %defaultListenAddress%

:: If user pressed escape
if "%localPort%"=="ESC" goto menu
if "%wslPort%"=="ESC" goto menu
if "%listenAddress%"=="ESC" goto menu

call :ruleExists %localPort%
if "%ruleExists%"=="0" (
    netsh advfirewall firewall add rule name="%ruleNamePattern% %localPort%" dir=in action=allow protocol=TCP localport=%localPort%
)
netsh interface portproxy add v4tov4 listenaddress=%listenAddress% listenport=%localPort% connectaddress=localhost connectport=%wslPort%
goto menu


:deleteRule
cls
echo Existing Rules:
echo.
call :displayRules
echo.
echo 0) Return to main menu
echo.
set /p choice="Enter the port number you wish to delete or 0 to return: "

if "%choice%"=="" goto menu
if "%choice%"=="0" goto menu

:: Count how many forwardings are associated with the chosen port
set "count=0"
for /f "tokens=1,2" %%a in ('netsh interface portproxy show all ^| findstr /C:" %choice% "') do (
    set /a count+=1
)

:: If there's only one forwarding, delete it
if "%count%"=="1" (
    for /f "tokens=1,2" %%a in ('netsh interface portproxy show all ^| findstr /C:" %choice% "') do (
        set detectedlistenAddress=%%a
        set detectedPort=%%b
    )
    netsh interface portproxy delete v4tov4 listenaddress=!detectedlistenAddress! listenport=!detectedPort!
    netsh advfirewall firewall delete rule name="%ruleNamePattern% %choice%"
    goto menu
)

:: If there are multiple forwardings, ask the user which one to delete
echo.
echo Multiple forwardings detected for port %choice%. Choose one to delete:
set "index=1"
for /f "tokens=1,2" %%a in ('netsh interface portproxy show all ^| findstr /C:" %choice% "') do (
    echo !index!^) %%a:%%b
    set "listenAddress!index!=%%a"
    set "port!index!=%%b"
    set /a index+=1
)
set allIndex=!index!
echo !allIndex!^) Delete all forwardings for port %choice%
echo.
set /p listenAddressChoice="Enter the number of the forwarding you wish to delete or !allIndex! to delete all: "

if "%listenAddressChoice%"=="!allIndex!" (
    for /l %%i in (1,1,!allIndex!) do (
        if defined listenAddress%%i (
            netsh interface portproxy delete v4tov4 listenaddress=!listenAddress%%i! listenport=%choice%
        )
    )
    netsh advfirewall firewall delete rule name="%ruleNamePattern% %choice%"
    goto menu
) else (
    set detectedlistenAddress=!listenAddress%listenAddressChoice%!
    set detectedPort=!port%listenAddressChoice%!
    echo [DEBUG] Deleting specific forwarding: !detectedlistenAddress!:!detectedPort!
    netsh interface portproxy delete v4tov4 listenaddress=!detectedlistenAddress! listenport=!detectedPort!
    goto menu
)
set detectedlistenAddress=!listenAddress%listenAddressChoice%!
netsh interface portproxy delete v4tov4 listenaddress=%detectedlistenAddress% listenport=%choice%
goto menu


:getUserInput
setlocal
set "promptText=%~1"
set "returnValue="
set "defaultVal=%~3"
set /p returnValue="%promptText%"
if not defined returnValue set returnValue=%defaultVal%
if "%returnValue%"=="" set returnValue=ESC
endlocal & set "%~2=%returnValue%"
exit /b
