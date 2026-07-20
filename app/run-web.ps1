# 启动 gym-os 前端(Flutter Web)
# 固定端口 8890 + 本地 CanvasKit(--no-web-resources-cdn,避开被墙的 gstatic)+ web-server 设备(浏览器无关)
# 用法:在 app/ 目录执行  .\run-web.ps1   然后浏览器开 http://localhost:8890
$env:Path = "D:\Develop\flutter\bin;" + $env:Path
Set-Location $PSScriptRoot
flutter run -d web-server --web-hostname=localhost --web-port=8890 --no-web-resources-cdn
