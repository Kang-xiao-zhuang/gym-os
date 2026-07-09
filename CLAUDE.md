# CLAUDE.md

## Project

GymOS

Personal Gym Operating System.

---

## Tech Stack

Backend

- Java 21 (JDK at D:\Develop\jdk\jdk21\jdk-21.0.10)
- Spring Boot 3.5
- Spring Data JPA (ddl-auto=validate)
- PostgreSQL on Supabase
- Spring Security + OAuth2 Resource Server (validates Supabase-issued JWT)
- Manual DTO mapping via static `of()` factories (no MapStruct)

Note: schema is owned in Supabase, NOT Flyway. Reference DDL/functions in backend/db/supabase-setup.sql.

Frontend

- Flutter
- Riverpod
- GoRouter
- http (not Dio)
- supabase_flutter (Auth + Storage), shared_preferences, fl_chart, image_picker

---

## Architecture

Backend: layered packages — common / config / controller / service / repository / entity / dto.

Frontend: feature-based — lib/features/<feature>/ (今天/计划/动作库/身体数据/训练历史/统计/我的), shared bits in lib/core.

---

## Coding Rules

- Never expose Entity directly.
- Always use DTO.
- RESTful API only.
- Unified Result<T> response.
- Global Exception Handler.
- Schema is managed in Supabase; entities must match it (ddl-auto=validate, no Flyway).
- Follow Clean Code principles.
- Prefer composition over inheritance.
- Write reusable widgets in Flutter.
- Keep UI minimal and distraction-free.

---

## Product Philosophy

GymOS is not a social platform.

GymOS is a Personal Gym Operating System.

Every feature should improve the user's training efficiency.

Avoid unnecessary complexity.

Focus on

Plan → Train → Record → Analyze → Improve.