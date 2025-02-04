REM filepath: /f:/FromGitHub/LoraReader/start.bat
@echo off
chcp 65001 >nul
title LoraReader

:: 设置颜色代码
set "GREEN=[32m"
set "BLUE=[34m"
set "RED=[31m"
set "YELLOW=[33m"
set "RESET=[0m"

:: 设置所需的版本和下载链接
set REQUIRED_PYTHON=3.11.9
set REQUIRED_NODE=22.13.1
set PYTHON_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
set NODE_URL=https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi
set GIT_URL=https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe

:: 创建临时下载目录
if not exist "temp" mkdir temp

:: 显示欢迎界面
:welcome
cls
echo %BLUE%╔════════════════════════════════════════╗
echo ║         LoraReader 启动管理器         ║
echo ╚════════════════════════════════════════╝%RESET%
echo.
echo %GREEN%[系统检查]%RESET%
echo  正在检查系统环境...

:: 进度条动画
setlocal enabledelayedexpansion
for /L %%i in (1,1,20) do (
    set "progress="
    for /L %%j in (1,1,%%i) do set "progress=!progress!■"
    echo [!progress!%RESET%] %%i%%0^%% \r
    ping -n 1 localhost >nul
)
echo.
echo %GREEN%[完成]%RESET% 系统检查完成
timeout /t 1 >nul

:: 检查并安装依赖
:check_dependencies
echo.
echo %YELLOW%[依赖检查]%RESET%
echo 即将检查并安装以下组件:
echo  %BLUE%▸%RESET% Git
echo  %BLUE%▸%RESET% Python %REQUIRED_PYTHON%
echo  %BLUE%▸%RESET% Node.js %REQUIRED_NODE%
echo.
choice /c YN /m "是否继续安装? (Y=是/N=否)"
if errorlevel 2 exit
if errorlevel 1 goto install

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

:: 主菜单界面
:menu
cls
echo %BLUE%╔════════════════════════════════════════╗
echo ║            LoraReader 菜单            ║
echo ╚════════════════════════════════════════╝%RESET%
echo.

:: 版本检查
echo %YELLOW%[版本检查中...]%RESET%
git remote update >nul 2>&1
git fetch >nul 2>&1
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set LOCAL_VERSION=%%a
for /f "tokens=*" %%a in ('git rev-parse origin/main') do set REMOTE_VERSION=%%a

if not "%LOCAL_VERSION%"=="%REMOTE_VERSION%" (
    echo %YELLOW%┌─ 版本信息 ───────────────────────┐
    echo │ 本地版本: %LOCAL_VERSION:~0,7%              │
    echo │ 远程版本: %REMOTE_VERSION:~0,7%              │
    echo └───────────────────────────────────┘%RESET%
    echo.
    choice /c YN /m "继续使用当前版本? (Y=是/N=更新)"
    if errorlevel 2 goto update
)

:show_menu
echo.
echo %GREEN%[可用操作]%RESET%
echo  %BLUE%[1]%RESET% 启动应用
echo  %BLUE%[2]%RESET% 检查更新
echo  %BLUE%[3]%RESET% 退出程序
echo.
choice /c 123 /n /m "请选择操作 (1-3): "
if errorlevel 3 exit
if errorlevel 2 goto update
if errorlevel 1 goto start

:update
echo.
echo %YELLOW%[更新检查]%RESET%
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
echo.
echo %GREEN%[启动服务]%RESET%
echo  %BLUE%▸%RESET% 正在启动后端服务...
start cmd /k "title LoraReader Backend && color 0B && call .venv\Scripts\activate && cd backend && python main.py"

echo  %BLUE%▸%RESET% 正在启动前端服务...
start cmd /k "title LoraReader Frontend && color 0A && cd LoraReader && npm run dev"

echo  %BLUE%▸%RESET% 等待服务启动...
ping -n 3 localhost >nul

echo  %BLUE%▸%RESET% 正在打开浏览器...
start http://localhost:5173

echo.
echo %GREEN%[启动完成]%RESET%
echo 请在浏览器中使用 LoraReader
pause
exit