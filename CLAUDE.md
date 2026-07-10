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

Note: schema is owned in Supabase, NOT Flyway. Reference SQL in backend/db/ — supabase-setup.sql (Storage policies + auth.users→public.users trigger), exercise-content.sql (exercise 要领/建议训练量 seed data).

Frontend

- Flutter
- Riverpod
- GoRouter
- http (not Dio)
- supabase_flutter (Auth + Storage), shared_preferences, fl_chart, image_picker, url_launcher

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
  Change tables on the Supabase side first, then make the entity match. When adding
  columns via a direct DB connection, the DDL MUST be committed (autocommit on) or it
  silently rolls back.
- Follow Clean Code principles.
- Prefer composition over inheritance.
- Write reusable widgets in Flutter.
- UI: 大众化、优雅、有温度的消费级观感 — NOT a dry/文绉绉/admin-table look. Use emoji + color
  liberally (per-body-part emoji & accent color, per-plan icon, flame difficulty), gradient
  hero cards, greeting-style home. Refined but friendly, not cold-minimal. Design system in
  lib/core/theme.dart; body-part color/emoji map in lib/core/body_part.dart.

---

## Product Philosophy

GymOS is not a social platform.

GymOS is a Personal Gym Operating System.

Every feature should improve the user's training efficiency.

Avoid unnecessary complexity.

Focus on

Plan → Train → Record → Analyze → Improve.