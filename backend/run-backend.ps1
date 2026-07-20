# 启动 gym-os 后端(Spring Boot,端口 8866)
# 必须用 JDK 21(机器默认 java 是 8,会编译失败);local profile 自动加载 application-local.yml 密钥
# 用法:在 backend/ 目录执行  .\run-backend.ps1
$env:JAVA_HOME = "D:\Develop\jdk\jdk21\jdk-21.0.10"
Set-Location $PSScriptRoot
.\mvnw.cmd -q -DskipTests spring-boot:run
