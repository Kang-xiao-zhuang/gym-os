# GymOS 🏋️

> Personal Gym Operating System —— 康小庄的健身 App，持续迭代，持续进步。

GymOS 不是健身社交平台，而是一款**个人训练操作系统**。核心理念是打通训练闭环：

**Plan（计划）→ Train（训练）→ Record（记录）→ Analyze（分析）→ Improve（改进）**

目标是帮用户**练得更好**，而不是在 App 里停留更久 —— 打开即练、无广告、无信息流、专注训练。

---

底部五个 tab：**今天 · 计划 · 训练历 · 数据 · 我的**。

### 核心闭环
- **今天** —— 打开直接开练：问候 + 本周战绩 + **「下一站」**(按激活计划自动推荐今天该练哪天 + 一键开始) + 今日训练(逐组记录 重量 × 次数、打勾自动弹组间休息倒计时、训练计时、实时总容量、完成生成总结入库) + 空手快速记录入口。
- **训练计划** —— 多计划管理，单屏编排(计划 → 训练日 → 动作)，可命名、自选 emoji 图标、设为「进行中」。
- **动作库** —— 动作增删改查，部位/器械/难度/说明，示范图上传至云存储。

### 训练历(月视图)
- **大格子月历** —— 每天格子里直接列出当天练的动作(部位配色) + ⭐ 破纪录星标。
- **就地下拉** —— 点某天在本周下方平滑展开完整明细(动作/组数/最重/PR)，「再练一次」一键复刻;点别天切换、再点收起。
- **本月战绩** —— 练了 X 天 / 当前连续 Y 天 / 总容量，外加「本周 N 次 · 已 X 天没练」频率提醒。

### 记录与分析
- **训练历史** —— 每次训练按时间归档，动作每组明细、总组数与总容量、破纪录徽章。
- **PR 破纪录** —— 训练中显示当前纪录，破纪录时庆祝页变金色;自重动作按单次总次数计纪录。
- **训练统计** —— 本周 / 连续 / 累计打卡 + 全年打卡热力图 + 成就徽章。
- **复盘洞察** —— 本月部位分布、停滞检测、近 30 天最大进步。
- **力量曲线** —— 单动作趋势：估算 1RM(Epley) / 最大重量 / 训练容量，带日期轴。
- **渐进超负荷助手** —— 记录时给出「上次做满了 → +2.5kg」建议，一键采用。
- **周报分享卡** —— 生成本周训练分享图。

### 身体
- **身体数据** —— 记录体重 / 体脂 / 围度，趋势曲线(按指标切换)，目标体重圆环进度。
- **💪 肌肉训练地图** —— 前 / 后身解剖图(SVG)，按**累计训练量**给各肌群上色，打开时从暗到亮"点亮"，一眼看出练得均不均。

### 我的
- 头像 / 昵称编辑、深色模式(跟随系统 / 浅色 / 深色)、**训练数据导出 / 导入**(CSV / JSON)、退出登录。

### 视觉
- 全局柔和渐变背景、路由淡入淡出、图片淡入 + 骨架屏、触觉反馈、消费级 emoji + 配色。

---

## 🧱 技术栈

**前端 (`app/`)**

- Flutter + Dart
- Riverpod（状态管理）
- GoRouter（路由 + 登录守卫）
- supabase_flutter（Auth + Storage）
- http（调用后端 API）
- fl_chart（趋势图）、flutter_svg（肌肉地图,ColorMapper 动态上色）、image_picker、shared_preferences、confetti

**后端 (`backend/`)**

- Java 21 + Spring Boot 3.5
- Spring Data JPA（`ddl-auto=validate`）
- Spring Security + OAuth2 Resource Server（校验 Supabase 签发的 JWT）
- 手写 DTO 映射（`of()` 工厂），统一 `Result<T>` 返回 + 全局异常处理

**数据 / 基础设施**

- PostgreSQL（托管于 Supabase）
- Supabase **Auth**（邮箱 + 密码，JWT 采用 ES256）
- Supabase **Storage**（动作示范图 / 头像，公开桶 `exercise-media`）

> 数据库 schema 由 Supabase 侧维护，后端只做 `validate` 校验、不使用 Flyway。
> 非表结构的数据库配置（Storage 策略、`auth.users → public.users` 同步触发器）见 `backend/db/supabase-setup.sql`。

---

## 📁 目录结构

```
gym-os/
├── app/                       # Flutter 前端
│   └── lib/
│       ├── config/            # 环境配置（Supabase URL / anon key / 后端地址）
│       ├── core/              # 主题、路由、通用组件、API 客户端
│       └── features/          # 按功能模块：today/workout/exercise/body/history/stats/profile/auth
├── backend/                   # Spring Boot 后端
│   ├── src/main/java/com/zk/gymos/
│   │   ├── common/            # Result / 全局异常 / BusinessException
│   │   ├── config/            # 安全配置（资源服务器）
│   │   ├── controller/ service/ repository/ entity/ dto/
│   │   └── security/
│   ├── src/main/resources/    # application.yml（application-local.yml 存密钥，已 gitignore）
│   └── db/supabase-setup.sql  # Supabase 侧一次性设置（存档参考）
└── README.md
```

---

## 🚀 本地运行

### 环境要求

- **JDK 21**（Spring Boot 3.5 需要 Java 17+）
- Flutter SDK（stable）
- 一个 Supabase 项目（PostgreSQL + Auth + Storage）

### 后端

1. 在 `backend/src/main/resources/` 新建 `application-local.yml`（该文件已被 gitignore，不要提交）：

   ```yaml
   spring:
     datasource:
       url: jdbc:postgresql://<host>:5432/postgres?sslmode=require
       username: <db-user>
       password: <db-password>
       driver-class-name: org.postgresql.Driver
   ```

2. 启动（默认端口 8866，需 JDK 21）：

   ```bash
   cd backend
   ./mvnw spring-boot:run
   ```

   > Windows 上机器默认 java 可能是 8，会编译失败 —— 先把 `JAVA_HOME` 指到 JDK 21。
   > 备有便捷脚本 `backend/run-backend.ps1`（已设好 JDK 21）。

### 前端

在 `app/lib/config/app_config.dart` 填入 Supabase URL、anon key 与后端地址，然后：

```bash
cd app
flutter pub get
flutter run -d web-server --web-hostname=localhost --web-port=8890 --no-web-resources-cdn
```

浏览器打开 http://localhost:8890，使用邮箱 + 密码注册 / 登录即可。备有便捷脚本 `app/run-web.ps1`。

> **`--no-web-resources-cdn` 很重要**：Flutter Web 默认从 `gstatic.com` 下载 CanvasKit 引擎，国内被墙会导致**白屏**;该参数把引擎打进本地、离线可用。

---

## 🗺️ Roadmap

- **已完成**：PR 破纪录 · 复盘洞察 · 力量曲线 · 渐进超负荷助手 · 成就徽章 · 周报 · 数据导出/导入 · 训练历月视图 · 计划「下一站」轮换 · 肌肉训练地图 · 全局渐变背景
- **规划中**：更写实的肌肉解剖 SVG · 训练过程本地持久化(断网不丢) · 部署上云 / Android 打包 · RIR/RPE 主观强度

---

_Made with 💪 by 康小庄_
