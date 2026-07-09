-- GymOS — Supabase 侧一次性设置（参考存档，已通过管理连接执行过）。
-- 说明：表结构由 Supabase 侧维护（ddl-auto=validate），本文件只记录“非表结构”的
-- 数据库侧配置，方便换环境时重放。不由应用自动执行。

-- ============================================================
-- 1) Storage：动作图片公开桶 + RLS 策略
-- ============================================================
insert into storage.buckets (id, name, public)
values ('exercise-media', 'exercise-media', true)
on conflict (id) do update set public = true;

drop policy if exists "exercise_media_read"   on storage.objects;
drop policy if exists "exercise_media_insert" on storage.objects;
drop policy if exists "exercise_media_update" on storage.objects;
drop policy if exists "exercise_media_delete" on storage.objects;

create policy "exercise_media_read"   on storage.objects for select to public        using (bucket_id = 'exercise-media');
create policy "exercise_media_insert" on storage.objects for insert to authenticated  with check (bucket_id = 'exercise-media');
create policy "exercise_media_update" on storage.objects for update to authenticated  using (bucket_id = 'exercise-media');
create policy "exercise_media_delete" on storage.objects for delete to authenticated  using (bucket_id = 'exercise-media');

-- ============================================================
-- 2) 新用户自动同步：auth.users -> public.users
--    （workout_plans.user_id 等外键指向 public.users，故注册后必须有 profile 行）
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, nickname, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nickname', ''), split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 回填历史用户
insert into public.users (id, nickname, email)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'nickname', ''), split_part(u.email, '@', 1)),
       u.email
from auth.users u
where not exists (select 1 from public.users p where p.id = u.id);
