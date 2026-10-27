-- ============================================================================
-- CloudBase 增量迁移 v2：日程时间段 + 用户头像档案
-- 使用：CloudBase 控制台 → 数据库 → SQL 编辑器 → 全部粘贴 → 执行
-- 说明：在你已经建好 5 张表的环境上执行即可（重复执行安全）。
-- ============================================================================

-- 1. 日程增加"结束时间"字段（配合"开始-结束"时间段）
alter table public.schedules
  add column if not exists end_time text not null default '';

-- 2. 用户档案表（昵称 + 头像）
create table if not exists public.profiles (
  id text primary key,
  nickname text not null default '',
  avatar_url text not null default '',
  created_at timestamptz default now()
);

-- 3. 授权 + RLS（放行 anon）
grant select, insert, update, delete on public.profiles to anon;

alter table public.profiles enable row level security;

create policy "anon_all_profiles" on public.profiles
  for all to anon using (true) with check (true);
