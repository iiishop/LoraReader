@echo off
:: 中文编码方案选择（二选一）
:: 方案1: ANSI + GBK (默认中文环境)
chcp 936 >nul

:: 方案2: UTF-8 + 65001 (需配置控制台字体)
:: chcp 65001 >nul

:: 获取 ANSI 转义字符
for /f %%i in ('powershell -command "Write-Host ([char]27)"') do set "ESC=%%i"

:: 设置颜色代码
set "GREEN=%ESC%[32m"
set "BLUE=%ESC%[34m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "RESET=%ESC%[0m"

:: 启用虚拟终端支持
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

title LoraReader
setlocal enabledelayedexpansion

:: 后续脚本内容保持不变...

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
echo  正在初始化环境...

:: 简化初始化动画
for /L %%i in (1,1,3) do (
    <nul set /p "=."
    ping -n 1 localhost >nul
)
echo.
echo %GREEN%[完成]%RESET% 环境准备就绪
timeout /t 1 >nul

:: 主安装流程
:main
cls
echo %BLUE%[依赖检查]%RESET%
set NEED_INSTALL=0

:: 检查 Git 安装
echo %BLUE%?%RESET% 检查 Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Git 未安装
    set NEED_INSTALL=1
) else (
    for /f "tokens=3" %%i in ('git --version') do (
        echo   %GREEN%?%RESET% Git 已安装 (版本: %%i)
    )
)

:: 检查 Python 安装
echo %BLUE%?%RESET% 检查 Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Python 未安装
    set NEED_INSTALL=1
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do (
        if "%%i" neq "%REQUIRED_PYTHON%" (
            echo   %YELLOW%!%RESET% 需要 Python %REQUIRED_PYTHON%，当前版本: %%i
            set NEED_INSTALL=1
        ) else (
            echo   %GREEN%?%RESET% Python 已安装 (版本: %%i)
        )
    )
)

:: 检查 Node.js 安装
echo %BLUE%?%RESET% 检查 Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   %RED%?%RESET% Node.js 未安装
    set NEED_INSTALL=1
) else (
    for /f "tokens=1 delims=v" %%i in ('node --version') do (
        if "%%i" neq "%REQUIRED_NODE%" (
            echo   %YELLOW%!%RESET% 需要 Node.js %REQUIRED_NODE%，当前版本: %%i
            set NEED_INSTALL=1
        ) else (
            echo   %GREEN%?%RESET% Node.js 已安装 (版本: %%i)
        )
    )
)

:: 判断是否需要安装
if %NEED_INSTALL% equ 1 (
    echo.
    echo %YELLOW%[提示]%RESET% 检测到缺少必要组件或版本不符
    choice /c YN /m "是否立即安装/更新? (Y/N)"
    if errorlevel 2 (
        echo %RED%[错误]%RESET% 必须安装所有依赖才能继续
        pause
        exit
    )
    goto do_install
) else (
    echo.
    echo %GREEN%[通过]%RESET% 所有依赖检查正常
    timeout /t 2 >nul
    goto setup_env
)

:: 安装组件流程
:do_install
cls
echo %BLUE%[组件安装]%RESET%

:: 安装 Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% 正在安装 Git...
    powershell -Command "Invoke-WebRequest '%GIT_URL%' -OutFile 'temp\git_install.exe'" || (
        echo %RED%[错误]%RESET% 下载 Git 失败
        choice /c YN /m "是否继续? (Y/N)"
        if errorlevel 2 exit
    )
    start /wait "" temp\git_install.exe /VERYSILENT /NORESTART
    set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
    echo %GREEN%?%RESET% Git 安装完成
)

:: 安装 Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% 正在安装 Python...
    powershell -Command "Invoke-WebRequest '%PYTHON_URL%' -OutFile 'temp\python_install.exe'" || (
        echo %RED%[错误]%RESET% 下载 Python 失败
        choice /c YN /m "是否继续? (Y/N)"
        if errorlevel 2 exit
    )
    start /wait "" temp\python_install.exe /quiet InstallAllUsers=1 PrependPath=1
    set "PATH=%ProgramFiles%\Python311;%PATH%"
    echo %GREEN%?%RESET% Python 安装完成
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do (
        if "%%i" neq "%REQUIRED_PYTHON%" (
            echo %BLUE%?%RESET% 正在升级 Python...
            powershell -Command "Invoke-WebRequest '%PYTHON_URL%' -OutFile 'temp\python_install.exe'" || (
                echo %RED%[错误]%RESET% 下载 Python 失败
                choice /c YN /m "是否继续? (Y/N)"
                if errorlevel 2 exit
            )
            start /wait "" temp\python_install.exe /quiet InstallAllUsers=1 PrependPath=1 /upgrade
            set "PATH=%ProgramFiles%\Python311;%PATH%"
            echo %GREEN%?%RESET% Python 升级完成
        )
    )
)

:: 安装 Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo %BLUE%?%RESET% 正在安装 Node.js...
    powershell -Command "Invoke-WebRequest '%NODE_URL%' -OutFile 'temp\node_install.msi'" || (
        echo %RED%[错误]%RESET% 下载 Node.js 失败
        choice /c YN /m "是否继续? (Y/N)"
        if errorlevel 2 exit
    )
    msiexec /i temp\node_install.msi /quiet /norestart
    set "PATH=%ProgramFiles%\nodejs;%PATH%"
    echo %GREEN%?%RESET% Node.js 安装完成
) else (
    for /f "tokens=1 delims=v" %%i in ('node --version') do (
        if "%%i" neq "%REQUIRED_NODE%" (
            echo %BLUE%?%RESET% 正在升级 Node.js...
            powershell -Command "Invoke-WebRequest '%NODE_URL%' -OutFile 'temp\node_install.msi'" || (
                echo %RED%[错误]%RESET% 下载 Node.js 失败
                choice /c YN /m "是否继续? (Y/N)"
                if errorlevel 2 exit
            )
            msiexec /i temp\node_install.msi /quiet /norestart
            set "PATH=%ProgramFiles%\nodejs;%PATH%"
            echo %GREEN%?%RESET% Node.js 升级完成
        )
    )
)

:: 环境初始化
:setup_env
echo.
echo %BLUE%[环境初始化]%RESET%

:: 创建 Python 虚拟环境
if not exist ".venv" (
    echo %BLUE%?%RESET% 正在创建虚拟环境...
    python -m venv .venv || (
        echo %RED%[错误]%RESET% 虚拟环境创建失败
        choice /c YN /m "是否继续? (Y/N)"
        if errorlevel 2 exit
    )
)

:: 安装 Python 依赖
echo %BLUE%?%RESET% 正在安装 Python 依赖...
call .venv\Scripts\activate
pip install --upgrade pip || (
    echo %RED%[错误]%RESET% pip 升级失败
    choice /c YN /m "是否继续? (Y/N)"
    if errorlevel 2 exit
)
pip install -r requirements.txt || (
    echo %RED%[错误]%RESET% 依赖安装失败
    choice /c YN /m "是否继续? (Y/N)"
    if errorlevel 2 exit
)

:: 安装 Node.js 依赖
echo %BLUE%?%RESET% 请手动安装 Node.js 依赖...
echo %YELLOW%[提示]%RESET% 请手动打开的窗口中执行以下命令:
echo   cd LoraReader
echo   npm install 

:: 主菜单界面
:menu
cls
echo =======================================
echo            LoraReader 控制中心
echo =======================================
echo.
echo %YELLOW%操作选项:%RESET%
echo.
echo   %GREEN%[1]%RESET% 启动应用程序
echo   %GREEN%[2]%RESET% 检查更新
echo   %GREEN%[3]%RESET% 退出程序
echo.

choice /c 123 /n /m "请选择操作 (1-3): "
if %errorlevel% equ 3 exit
if %errorlevel% equ 2 goto update
if %errorlevel% equ 1 goto start

:: 更新功能
:update
echo.
echo %BLUE%[更新检查]%RESET%
git fetch
set LOCAL_COMMIT=
set REMOTE_COMMIT=
for /f "delims=" %%i in ('git rev-parse HEAD') do set LOCAL_COMMIT=%%i
for /f "delims=" %%i in ('git rev-parse origin/main') do set REMOTE_COMMIT=%%i

if "%LOCAL_COMMIT%" neq "%REMOTE_COMMIT%" (
    echo %YELLOW%[更新可用]%RESET%
    echo 本地版本: %LOCAL_COMMIT:~0,7%
    echo 远程版本: %REMOTE_COMMIT:~0,7%
    choice /c YN /m "是否立即更新? (Y/N)"
    if %errorlevel% equ 2 goto menu
    git pull origin main || (
        echo %RED%[错误]%RESET% 更新失败
        choice /c YN /m "是否继续? (Y/N)"
        if errorlevel 2 exit
    )
    echo.
    echo %GREEN%[成功]%RESET% 代码更新完成
    goto setup_env
) else (
    echo %GREEN%[提示]%RESET% 当前已是最新版本
    timeout /t 2 >nul
    goto menu
)

:: 启动服务
:start
echo.
echo %BLUE%[服务启动]%RESET%
start "LoraReader 后端" cmd /k "call .venv\Scripts\activate && python backend/main.py"
start "LoraReader 前端" cmd /k "cd LoraReader && npm run dev"
timeout /t 5 >nul
start "" http://localhost:5173
echo %GREEN%[完成]%RESET% 服务已启动，浏览器即将打开
echo 注意：服务完全启动可能需要 30-60 秒
pause
exit

:: 清理临时文件
if exist "temp" rd /s /q temp