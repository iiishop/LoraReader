REM filepath: /f:/FromGitHub/LoraReader/start.bat
@echo off
title LoraReader

:: 检查 Python 和 Node.js 是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed.
    pause
    exit
)

node --version >nul 2>&1
if errorlevel 1 (
    echo Node.js is not installed.
    pause
    exit
)

:: 启动后端服务
start cmd /k "call .venv\Scripts\activate && cd backend && python main.py"

:: 启动前端服务
start cmd /k "cd LoraReader && npm install && npm run dev"

:: 等待前端服务启动
timeout /t 1

:: 打开默认浏览器访问前端页面
start http://localhost:5173