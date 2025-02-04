REM filepath: /f:/FromGitHub/LoraReader/start.bat
@echo off
title LoraReader

:: 检查 Git 是否安装
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Please install Git first. (请先安装 Git)
    pause
    exit
)

:: 检查 Python 和 Node.js 是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed. (请先安装 Python)
    pause
    exit
)

node --version >nul 2>&1
if errorlevel 1 (
    echo Node.js is not installed. (请先安装 Node.js)
    pause
    exit
)

:: 添加更新选项菜单
:menu
cls
echo ================================
echo LoraReader Launch Menu (启动菜单)
echo ================================
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
pause
goto menu

:start
:: 启动后端服务
start cmd /k "call .venv\Scripts\activate && cd backend && python main.py"

:: 启动前端服务
start cmd /k "cd LoraReader && npm install && npm run dev"

:: 等待前端服务启动
timeout /t 1

:: 打开默认浏览器访问前端页面
start http://localhost:5173

exit