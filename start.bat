@echo off
:: ���ı��뷽��ѡ�񣨶�ѡһ��
:: ����1: ANSI + GBK (Ĭ�����Ļ���)
chcp 936 >nul

:: ����2: UTF-8 + 65001 (�����ÿ���̨����)
:: chcp 65001 >nul

:: ��ȡ ANSI ת���ַ�
for /f %%i in ('powershell -command "Write-Host ([char]27)"') do set "ESC=%%i"

:: ������ɫ����
set "GREEN=%ESC%[32m"
set "BLUE=%ESC%[34m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "RESET=%ESC%[0m"

:: ���������ն�֧��
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

title LoraReader
setlocal enabledelayedexpansion

:: �����ű����ݱ��ֲ���...

:: ��������İ汾����������
set REQUIRED_PYTHON=3.11.9
set REQUIRED_NODE=22.13.1
set PYTHON_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
set NODE_URL=https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi
set GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe

:: ������ʱ����Ŀ¼
if not exist "temp" mkdir temp

:: ��ʾ��ӭ����
:welcome
cls
echo %BLUE%�X�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�[
echo �U         LoraReader ����������         �U
echo �^�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�T�a%RESET%
echo.
echo %GREEN%[ϵͳ���]%RESET%
echo  ���ڳ�ʼ������...

:: �򻯳�ʼ������
for /L %%i in (1,1,3) do (
    <nul set /p "=."
    ping -n 1 localhost >nul
)
echo.
echo %GREEN%[���]%RESET% ����׼������
timeout /t 1 >nul

:: ����װ����
:main
cls
echo %BLUE%[�������]%RESET%
set NEED_INSTALL=0

:: ��� Git ��װ
echo %BLUE%?%RESET% ��� Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Git δ��װ
    set NEED_INSTALL=1
) else (
    for /f "tokens=3" %%i in ('git --version') do (
        echo   %GREEN%?%RESET% Git �Ѱ�װ (�汾: %%i)
    )
)

:: ��� Python ��װ
echo %BLUE%?%RESET% ��� Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Python δ��װ
    set NEED_INSTALL=1
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do (
        if "%%i" neq "%REQUIRED_PYTHON%" (
            echo   %YELLOW%!%RESET% ��Ҫ Python %REQUIRED_PYTHON%����ǰ�汾: %%i
            set NEED_INSTALL=1
        ) else (
            echo   %GREEN%?%RESET% Python �Ѱ�װ (�汾: %%i)
        )
    )
)

:: ��� Node.js ��װ
echo %BLUE%?%RESET% ��� Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Node.js δ��װ
    set NEED_INSTALL=1
) else (
    for /f "tokens=1 delims=v" %%i in ('node --version') do (
        if "%%i" neq "%REQUIRED_NODE%" (
            echo   %YELLOW%!%RESET% ��Ҫ Node.js %REQUIRED_NODE%����ǰ�汾: %%i
            set NEED_INSTALL=1
        ) else (
            echo   %GREEN%?%RESET% Node.js �Ѱ�װ (�汾: %%i)
        )
    )
)

:: �ж��Ƿ���Ҫ��װ
if %NEED_INSTALL% equ 1 (
    echo.
    echo %YELLOW%[��ʾ]%RESET% ��⵽ȱ�ٱ�Ҫ�����汾����
    choice /c YN /m "�Ƿ�������װ/����? (Y/N)"
    if errorlevel 2 (
        echo %RED%[����]%RESET% ���밲װ�����������ܼ���
        pause
        exit
    )
    goto do_install
) else (
    echo.
    echo %GREEN%[ͨ��]%RESET% ���������������
    timeout /t 2 >nul
    goto setup_env
)

:: ��װ�������
:do_install
cls
echo %BLUE%[�����װ]%RESET%

:: ��װ Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% ���ڰ�װ Git...
    powershell -Command "Invoke-WebRequest '%GIT_URL%' -OutFile 'temp\git_install.exe'" || (
        echo %RED%[����]%RESET% ���� Git ʧ��
        choice /c YN /m "�Ƿ����? (Y/N)"
        if errorlevel 2 exit
    )
    start /wait "" temp\git_install.exe /VERYSILENT /NORESTART
    set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
    echo %GREEN%?%RESET% Git ��װ���
)

:: ��װ Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% ���ڰ�װ Python...
    powershell -Command "Invoke-WebRequest '%PYTHON_URL%' -OutFile 'temp\python_install.exe'" || (
        echo %RED%[����]%RESET% ���� Python ʧ��
        choice /c YN /m "�Ƿ����? (Y/N)"
        if errorlevel 2 exit
    )
    start /wait "" temp\python_install.exe /quiet InstallAllUsers=1 PrependPath=1
    set "PATH=%ProgramFiles%\Python311;%PATH%"
    echo %GREEN%?%RESET% Python ��װ���
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do (
        if "%%i" neq "%REQUIRED_PYTHON%" (
            echo %BLUE%?%RESET% �������� Python...
            powershell -Command "Invoke-WebRequest '%PYTHON_URL%' -OutFile 'temp\python_install.exe'" || (
                echo %RED%[����]%RESET% ���� Python ʧ��
                choice /c YN /m "�Ƿ����? (Y/N)"
                if errorlevel 2 exit
            )
            start /wait "" temp\python_install.exe /quiet InstallAllUsers=1 PrependPath=1 /upgrade
            set "PATH=%ProgramFiles%\Python311;%PATH%"
            echo %GREEN%?%RESET% Python �������
        )
    )
)

:: ��װ Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% ���ڰ�װ Node.js...
    powershell -Command "Invoke-WebRequest '%NODE_URL%' -OutFile 'temp\node_install.msi'" || (
        echo %RED%[����]%RESET% ���� Node.js ʧ��
        choice /c YN /m "�Ƿ����? (Y/N)"
        if errorlevel 2 exit
    )
    msiexec /i temp\node_install.msi /quiet /norestart
    set "PATH=%ProgramFiles%\nodejs;%PATH%"
    echo %GREEN%?%RESET% Node.js ��װ���
) else (
    for /f "tokens=1 delims=v" %%i in ('node --version') do (
        if "%%i" neq "%REQUIRED_NODE%" (
            echo %BLUE%?%RESET% �������� Node.js...
            powershell -Command "Invoke-WebRequest '%NODE_URL%' -OutFile 'temp\node_install.msi'" || (
                echo %RED%[����]%RESET% ���� Node.js ʧ��
                choice /c YN /m "�Ƿ����? (Y/N)"
                if errorlevel 2 exit
            )
            msiexec /i temp\node_install.msi /quiet /norestart
            set "PATH=%ProgramFiles%\nodejs;%PATH%"
            echo %GREEN%?%RESET% Node.js �������
        )
    )
)

:: ������ʼ��
:setup_env
echo.
echo %BLUE%[������ʼ��]%RESET%

:: ���� Python ���⻷��
if not exist ".venv" (
    echo %BLUE%?%RESET% ���ڴ������⻷��...
    python -m venv .venv || (
        echo %RED%[����]%RESET% ���⻷������ʧ��
        choice /c YN /m "�Ƿ����? (Y/N)"
        if errorlevel 2 exit
    )
)

:: ��װ Python ����
echo %BLUE%?%RESET% ���ڰ�װ Python ����...
call .venv\Scripts\activate
pip install --upgrade pip || (
    echo %RED%[����]%RESET% pip ����ʧ��
    choice /c YN /m "�Ƿ����? (Y/N)"
    if errorlevel 2 exit
)
pip install -r requirements.txt || (
    echo %RED%[����]%RESET% ������װʧ��
    choice /c YN /m "�Ƿ����? (Y/N)"
    if errorlevel 2 exit
)

:: ��װ Node.js ����
echo %BLUE%?%RESET% ���ֶ���װ Node.js ����...
echo %YELLOW%[��ʾ]%RESET% ���ֶ��򿪵Ĵ�����ִ����������:
echo   cd LoraReader
echo   npm install 

:: ���˵�����
:menu
cls
echo =======================================
echo            LoraReader ��������
echo =======================================
echo.
echo %YELLOW%����ѡ��:%RESET%
echo.
echo   %GREEN%[1]%RESET% ����Ӧ�ó���
echo   %GREEN%[2]%RESET% ������
echo   %GREEN%[3]%RESET% �˳�����
echo.

choice /c 123 /n /m "��ѡ����� (1-3): "
if %errorlevel% equ 3 exit
if %errorlevel% equ 2 goto update
if %errorlevel% equ 1 goto start

:: ���¹���
:update
echo.
echo %BLUE%[���¼��]%RESET%
git fetch
set LOCAL_COMMIT=
set REMOTE_COMMIT=
for /f "delims=" %%i in ('git rev-parse HEAD') do set LOCAL_COMMIT=%%i
for /f "delims=" %%i in ('git rev-parse origin/main') do set REMOTE_COMMIT=%%i

if "%LOCAL_COMMIT%" neq "%REMOTE_COMMIT%" (
    echo %YELLOW%[���¿���]%RESET%
    echo ���ذ汾: %LOCAL_COMMIT:~0,7%
    echo Զ�̰汾: %REMOTE_COMMIT:~0,7%
    choice /c YN /m "�Ƿ���������? (Y/N)"
    if %errorlevel% equ 2 goto menu
    git pull origin main || (
        echo %RED%[����]%RESET% ����ʧ��
        choice /c YN /m "�Ƿ����? (Y/N)"
        if errorlevel 2 exit
    )
    echo.
    echo %GREEN%[�ɹ�]%RESET% ����������
    goto setup_env
) else (
    echo %GREEN%[��ʾ]%RESET% ��ǰ�������°汾
    timeout /t 2 >nul
    goto menu
)

:: ��������
:start
echo.
echo %BLUE%[��������]%RESET%
start "LoraReader ���" cmd /k "call .venv\Scripts\activate && python backend/main.py"
start "LoraReader ǰ��" cmd /k "cd LoraReader && npm run dev"
timeout /t 5 >nul
start "" http://localhost:5173
echo %GREEN%[���]%RESET% �����������������������
echo ע�⣺������ȫ����������Ҫ 30-60 ��
pause
exit

:: ������ʱ�ļ�
if exist "temp" rd /s /q temp