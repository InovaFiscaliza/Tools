@echo off
setlocal enabledelayedexpansion

:: -------------------------------------------------------
:: Script by Anatel - Agência Nacional de Telecomunicações
:: Escritório de Inovação - InovaFiscaliza	<https:://github.com/InovaFiscaliza>
:: Version: 1.0
:: Date: 2024-11-21
:: -------------------------------------------------------

:: -------------------------------------------------------
:: Define variables
set "TITLE=Instalador do SCH"
set DOWNLOAD_URL=https://github.com/InovaFiscaliza/.github/releases/download/SCH/SCH.zip
set ZIP_FILE=%TEMP%\SCH.zip
set INSTALL_DIR=%USERPROFILE%\AppData\Roaming\ANATEL\SCH
set TARGET_EXE=%INSTALL_DIR%\SCH.exe
set SHORTCUT_NAME=SCH.lnk
set SHORTCUT_FOLDER=%ProgramData%\Microsoft\Windows\Start Menu\Programs\Anatel

:: -------------------------------------------------------
:: Get console width
for /f "tokens=2 delims=:" %%a in ('mode con ^| findstr "Columns"') do set "COLUMNS=%%a"
set "COLUMNS=%COLUMNS: =%"

:: Define the title
set /a PADDING=(%COLUMNS% - 1 - len(TITLE)) / 2
set "SPACES="
for /l %%i in (1,1,%PADDING%) do set "SPACES=!SPACES! "

:: Create horizontal line
set "LINE="
for /l %%i in (1,1,%COLUMNS%) do set "LINE=!LINE!~"

:: Display splash message
cls
echo !LINE!
echo !SPACES!%TITLE%
echo !LINE!
echo.
echo Pressione qualquer tecla para continuar...
pause >nul

:: -------------------------------------------------------
:: Check requirements
echo Verificando requisitos...
if not exist "C:\Program Files\MATLAB\MATLAB Runtime\R2024a\VersionInfo.xml" (
    echo Erro: MATLAB Runtime R2024a é necessário.
    echo Por favor, instale o MATLAB Runtime R2024a e tente novamente.
    echo O instalador está disponível em:
    start https://anatel365.sharepoint.com/:u:/s/InovaFiscaliza/EVq5RKKSiHJKiy3RTPRv_0UBOV_OuJ3d5A2E3rYkh8Kh9g?e=rwoeXQ
    exit /b 2
)

:: -------------------------------------------------------
:: Download the file
echo Baixando arquivos do repositório...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%'"
if %ERRORLEVEL% neq 0 (
    echo Erro: Falha ao realizar o download de SCH.zip
    echo Por favor, verifique sua conexão com a internet e tente novamente.
    exit /b 1
)

:: -------------------------------------------------------
:: Create the installation folder
echo Criando pasta de instalação...
if exist "%INSTALL_DIR%" (
    echo Erro: A pasta de instalação já existe.
    echo Por favor, utilize a opção de atualização ou remova a pasta '%INSTALL_DIR%' e tente novamente.
    exit /b 3
) else (
    mkdir "%INSTALL_DIR%" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Erro: Falha ao criar a pasta de instalação.
        echo Por favor, verifique as permissões de escrita e tente novamente.
        exit /b 4
    )
)

:: -------------------------------------------------------
:: Extract the content of the zip file
echo Extraindo arquivos...
tar -xf "%ZIP_FILE%" -C "%INSTALL_DIR%"
if %ERRORLEVEL% neq 0 (
    echo Erro: Falha ao extrair os arquivos.
    echo Por favor, verifique o arquivo '%ZIP_FILE%' e tente novamente.
    exit /b 5
) else (
    del "%ZIP_FILE%"
    if %ERRORLEVEL% neq 0 (
        echo Erro: Falha ao excluir o arquivo '%ZIP_FILE%'.
        echo Por favor, exclua manualmente. Instalação seguirá normalmente.
    )
)

:: -------------------------------------------------------
:: Create shortcut in the Start Menu
echo Criando atalho no menu Iniciar...
if not exist "%SHORTCUT_FOLDER%" mkdir "%SHORTCUT_FOLDER%"
powershell -Command ^
  "$ws = New-Object -ComObject WScript.Shell; ^
   $shortcut = $ws.CreateShortcut('%SHORTCUT_FOLDER%\%SHORTCUT_NAME%'); ^
   $shortcut.TargetPath = '%TARGET_EXE%'; ^
   $shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
   $shortcut.Save()"
if %ERRORLEVEL% neq 0 (
    echo Erro: Falha ao criar o atalho no menu Iniciar.
    echo Por favor, crie manualmente o atalho para '%TARGET_EXE%' na pasta '%SHORTCUT_FOLDER%'.
    exit /b 6
)

:: -------------------------------------------------------
:: End of the installation
echo Instalação concluída com sucesso.
echo.
echo Pressione qualquer tecla para continuar...
pause >nul

exit 0
