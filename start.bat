REM filepath: /f:/FromGitHub/LoraReader/start.bat
@echo off
title LoraReader

:: 设置所需的版本和下载链接
set REQUIRED_PYTHON=3.11.9
set REQUIRED_NODE=22.13.1
set PYTHON_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
set NODE_URL=https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi
set GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe

:: 创建临时下载目录
if not exist "temp" mkdir temp

:: 检查并安装依赖
:check_dependencies
cls
echo ================================
echo Welcome to LoraReader Setup (欢迎使用 LoraReader 安装程序)
echo ================================
echo The following software will be installed if not present: (将会安装以下软件:)
echo - Git
echo - Python %REQUIRED_PYTHON%
echo - Node.js %REQUIRED_NODE%
echo.
set /p confirm="Continue with installation? (Y/N) (是否继续安装?) [Y]: "
if /i "%confirm%"=="" goto install
if /i "%confirm%"=="y" goto install
if /i "%confirm%"=="Y" goto install
exit

:install
cls
echo ================================
echo Checking dependencies... (检查依赖...)
echo ================================

:: 检查 Git
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Downloading... (未安装 Git，正在下载...)
    powershell -Command "& {Invoke-WebRequest -Uri '%GIT_URL%' -OutFile 'temp\git-installer.exe'}"
    echo Installing Git... (正在安装 Git...)
    start /wait temp\git-installer.exe /VERYSILENT /NORESTART
    if errorlevel 1 (
        echo Failed to install Git. (Git 安装失败)
        echo Please download and install manually from: (请手动下载安装:)
        echo https://git-scm.com/downloads
        pause
        exit
    )
)

:: 检查 Python 版本
python --version 2>nul | find "%REQUIRED_PYTHON%" >nul
if errorlevel 1 (
    echo Python %REQUIRED_PYTHON% is not installed. Downloading... (未安装指定版本的 Python，正在下载...)
    powershell -Command "& {Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile 'temp\python-installer.exe'}"
    echo Installing Python... (正在安装 Python...)
    start /wait temp\python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    if errorlevel 1 (
        echo Failed to install Python. (Python 安装失败)
        echo Please download and install manually from: (请手动下载安装:)
        echo https://www.python.org/downloads/release/python-3119/
        pause
        exit
    )
)

:: 检查 Node.js 版本
node --version 2>nul | find "v%REQUIRED_NODE%" >nul
if errorlevel 1 (
    echo Node.js %REQUIRED_NODE% is not installed. Downloading... (未安装指定版本的 Node.js，正在下载...)
    powershell -Command "& {Invoke-WebRequest -Uri '%NODE_URL%' -OutFile 'temp\node-installer.msi'}"
    echo Installing Node.js... (正在安装 Node.js...)
    start /wait msiexec /i temp\node-installer.msi /quiet /norestart
    if errorlevel 1 (
        echo Failed to install Node.js. (Node.js 安装失败)
        echo Please download and install manually from: (请手动下载安装:)
        echo https://nodejs.org/
        pause
        exit
    )
)

:: 创建并激活虚拟环境
if not exist ".venv" (
    echo Creating Python virtual environment... (创建 Python 虚拟环境...)
    python -m venv .venv
    if errorlevel 1 (
        echo Failed to create virtual environment. (创建虚拟环境失败)
        pause
        exit
    )
)

:: 清理临时文件
if exist "temp" rd /s /q temp

:: 安装依赖函数
:install_dependencies
echo Installing Python requirements... (安装 Python 依赖...)
call .venv\Scripts\activate && python -m pip install --upgrade pip && pip install -r requirements.txt
if errorlevel 1 (
    echo Failed to install Python requirements. (Python 依赖安装失败)
    pause
    exit
)

echo Installing Node.js dependencies... (安装 Node.js 依赖...)
cd LoraReader && npm install
if errorlevel 1 (
    echo Failed to install Node.js dependencies. (Node.js 依赖安装失败)
    pause
    exit
)
cd ..

:: 添加更新选项菜单
:menu
cls
echo ================================
echo LoraReader Launch Menu (启动菜单)
echo ================================

:: 检查版本差异
echo Checking version differences... (检查版本差异...)
git remote update >nul 2>&1
git fetch >nul 2>&1

:: 获取版本信息
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set LOCAL_VERSION=%%a
for /f "tokens=*" %%a in ('git rev-parse origin/main') do set REMOTE_VERSION=%%a

:: 比较版本
if not "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    echo.
    echo Warning: Your version differs from the remote version (警告：本地版本与远程版本不同)
    echo Local Version (本地版本): %LOCAL_VERSION:~0,7%
    echo Remote Version (远程版本): %REMOTE_VERSION:~0,7%
    echo.
    set /p continue="Continue without updating? (Y/N) (是否继续运行而不更新?) [Y]: "
    if /i "%continue%"=="" goto show_menu
    if /i "%continue%"=="y" goto show_menu
    if /i "%continue%"=="Y" goto show_menu
    
    set /p update="Update to latest version? (Y/N) (是否更新到最新版本?) [Y]: "
    if /i "%update%"=="" goto update
    if /i "%update%"=="y" goto update
    if /i "%update%"=="Y" goto update
    goto menu
)

:show_menu
echo 1. Start Application (启动应用)
echo 2. Check for Updates (检查更新)
echo 3. Exit (退出)
echo ================================
set /p choice="Please choose (1-3) (请选择 1-3): "

if "%choice%"=="1" goto start
if "%choice%"=="2" goto update
if "%choice%"=="3" exit
goto menu

:update
echo Checking for updates... (正在检查更新...)
:: 如果 .git 目录不存在，初始化为 git 仓库
if not exist ".git" (
    git init
    git remote add origin https://github.com/iiishop/LoraReader.git
)

:: 保存当前的修改（如果有的话）
git stash

:: 获取最新的更改
git pull origin main
if errorlevel 1 (
    echo Update failed. Restoring previous version... (更新失败，正在恢复之前的版本...)
    git stash pop
    pause
    goto menu
)

:: 恢复本地修改（如果有的话）
git stash pop

echo Update completed! (更新完成！)
set /p confirm="Install new dependencies? (Y/N) (是否安装新依赖?) [Y]: "
if /i "%confirm%"=="" (goto update_deps)
if /i "%confirm%"=="y" (goto update_deps)
if /i "%confirm%"=="Y" (goto update_deps)
goto menu

:update_deps
echo Installing new dependencies... (安装新依赖...)
call :install_dependencies
pause
goto menu

:start
:: 启动后端服务
start cmd /k "call .venv\Scripts\activate && cd backend && python main.py"

:: 启动前端服务
start cmd /k "cd LoraReader && npm run dev"

:: 等待前端服务启动
timeout /t 1

:: 打开默认浏览器访问前端页面
start http://localhost:5173

exit