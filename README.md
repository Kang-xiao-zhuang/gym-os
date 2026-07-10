# GymOS 🏋️

> Personal Gym Operating System —— 康小庄的健身 App，持续迭代，持续进步。

GymOS 不是健身社交平台，而是一款**个人训练操作系统**。核心理念是打通训练闭环：

**Plan（计划）→ Train（训练）→ Record（记录）→ Analyze（分析）→ Improve（改进）**

目标是帮用户**练得更好**，而不是在 App 里停留更久 —— 打开即练、无广告、无信息流、专注训练。

---

## ✨ 功能

- **今天** —— 打开直接开练：选进行中的计划与训练日，逐组记录（重量 × 次数）、打勾自动弹出组间休息倒计时，训练计时、实时总容量，完成训练生成总结并入库。
- **训练计划** —— 多计划管理，单屏编排（计划 → 训练日 → 动作），可命名、自选 emoji 图标、设为「进行中」。
- **动作库** —— 动作增删改查，部位/器械/难度/说明，示范图上传至云存储。
- **身体数据** —— 记录体重 / 体脂 / 围度，趋势曲线图（按指标切换），目标体重圆环进度。
- **训练历史** —— 每次训练按时间归档，可查看每个动作的每组明细、总组数与总容量。
- **训练统计** —— 本周 / 连续 / 累计打卡天数 + 打卡月历热图。
- **我的** —— 头像 / 昵称编辑、深色模式（跟随系统 / 浅色 / 深色）、退出登录。

---

## 🧱 技术栈

**前端 (`app/`)**

- Flutter + Dart
- Riverpod（状态管理）
- GoRouter（路由 + 登录守卫）
- supabase_flutter（Auth + Storage）
- http（调用后端 API）
- fl_chart（趋势图）、image_picker、shared_preferences

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

2. 启动（默认端口 8866）：

   ```bash
   cd backend
   ./mvnw spring-boot:run
   ```

### 前端

在 `app/lib/config/app_config.dart` 填入 Supabase URL、anon key 与后端地址，然后：

```bash
cd app
flutter pub get
flutter run -d chrome        # 或 -d web-server --web-port=5599
```

浏览器打开对应地址，使用邮箱 + 密码注册 / 登录即可。

---

## 🗺️ Roadmap

- **进行中**：逐组「上次成绩」提示、PR 个人记录、训练过程本地持久化
- **规划中**：渐进超负荷推荐、训练量分析、更多可视化面板

---

_Made with 💪 by 康小庄_
