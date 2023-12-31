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
echo 3) Display Firewall Rule for port
echo 4) Display all Firewall rules "%ruleNamePattern% *"
echo 5) Display all port forwardings
echo 0) Exit
echo.
set /p option="Choose an option: "
goto option-%option% 2>nul
goto menu


:option-0
    exit

:option-1
    call :createRule
    goto menu

:option-2
    call :deleteRule
    goto menu

:option-3
    call :displayFirewallRuleForPort
    goto menu

:option-4
    call :displayAllFirewallRuleNamePattern
    goto menu

:option-5
    call :displayPortForwardings
    goto menu



:displayPortForwardings
netsh interface portproxy show all
echo.
pause
goto menu


:displayFirewallRuleForPort
set /p port="Enter the port number for which you want to see the firewall rules: "
if not defined port (
    echo No port number provided.
    pause
    goto menu
)

echo.
echo Showing firewall rules for port %port%:
echo --------------------------------------------------
netsh advfirewall firewall show rule name="%ruleNamePattern% %port%"
echo.
pause
goto menu

:displayAllFirewallRuleNamePattern
netsh advfirewall firewall show rule name=all | find "%ruleNamePattern%"
echo.
pause


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
:: Step 1: Create firewall rules ports list
set "portsList="
for /f "tokens=*" %%l in ('netsh advfirewall firewall show rule name^=all ^| find "%ruleNamePattern%"') do (
    for %%p in (%%l) do set "portNum=%%p"
    if not "!portNum!"=="" set "portsList=!portsList! !portNum!"
    set "hasRules=1"
)

:: Paso 2: Find firewall rule port and matching port forwardings
for %%p in (%portsList%) do (
    if not "%%p"=="" (
        echo Firewall Rule: %ruleNamePattern% %%p
        for /f "tokens=1,2,3,4" %%a in ('netsh interface portproxy show all ^| findstr /C:"%%p"') do (
            echo     %%a:%%b to %%c:%%d
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
set defaultListenIP=0.0.0.0
set defaultRemoteIP=any

:: Reset user input values
set "localPort="
set "wslPort="
set "listenIP="
set "remoteIP="

call :getUserInput "Enter the local port (default: %defaultLocalPort%): " localPort %defaultLocalPort%
call :getUserInput "Enter the WSL2 port (default: %defaultWslPort%): " wslPort %defaultWslPort%
call :getUserInput "Enter the listen IP (default: %defaultListenIP%): " listenIP %defaultListenIP%
call :getUserInput "Enter the remote IP or mask (default: %defaultRemoteIP%): " remoteIP %defaultRemoteIP%

:: If user pressed escape
if "%localPort%"=="ESC" goto menu
if "%wslPort%"=="ESC" goto menu
if "%listenIP%"=="ESC" goto menu
if "%remoteIP%"=="ESC" goto menu

call :ruleExists %localPort%
if "%ruleExists%"=="0" (
    netsh advfirewall firewall add rule name="%ruleNamePattern% %localPort%" dir=in action=allow protocol=TCP localport=%localPort% remoteip=%remoteIP%
)
netsh interface portproxy add v4tov4 listenaddress=%listenIP% listenport=%localPort% connectaddress=localhost connectport=%wslPort%
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
        set detectedListenIP=%%a
        set detectedPort=%%b
    )
    netsh interface portproxy delete v4tov4 listenaddress=!detectedListenIP! listenport=!detectedPort!
    netsh advfirewall firewall delete rule name="%ruleNamePattern% %choice%"
    goto menu
)

:: If there are multiple forwardings, ask the user which one to delete
echo.
echo Multiple forwardings detected for port %choice%. Choose one to delete:
set "index=1"
for /f "tokens=1,2" %%a in ('netsh interface portproxy show all ^| findstr /C:" %choice% "') do (
    echo !index!^) %%a:%%b
    set "listenIP!index!=%%a"
    set "port!index!=%%b"
    set /a index+=1
)
set allIndex=!index!
echo !allIndex!^) Delete all forwardings for port %choice%
echo.
set /p listenIPChoice="Enter the number of the forwarding you wish to delete or !allIndex! to delete all: "

if "%listenIPChoice%"=="!allIndex!" (
    for /l %%i in (1,1,!allIndex!) do (
        if defined listenIP%%i (
            netsh interface portproxy delete v4tov4 listenaddress=!listenIP%%i! listenport=%choice%
        )
    )
    netsh advfirewall firewall delete rule name="%ruleNamePattern% %choice%"
    goto menu
) else (
    set detectedListenIP=!listenIP%listenIPChoice%!
    set detectedPort=!port%listenIPChoice%!
    netsh interface portproxy delete v4tov4 listenaddress=!detectedListenIP! listenport=!detectedPort!
    goto menu
)


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
