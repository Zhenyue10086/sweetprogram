-- ============================================================================
-- CloudBase PostgreSQL 建表脚本（PostgREST 规范，与 Supabase 同构）
-- 使用：CloudBase 控制台 → 数据库 → SQL 编辑器 → 全部粘贴 → 执行
-- ============================================================================

-- 1. 建表 --------------------------------------------------------------------
create table if not exists public.anniversaries (
  id text primary key,
  title text not null,
  date date not null,
  created_at timestamptz default now()
);

create table if not exists public.schedules (
  id text primary key,
  title text not null,
  time text not null default '12:00',
  date date not null,
  created_at timestamptz default now()
);

create table if not exists public.periods (
  id text primary key,
  start date not null,
  duration int not null default 5,
  created_at timestamptz default now()
);

create table if not exists public.moments (
  id text primary key,
  content text not null default '',
  images jsonb not null default '[]'::jsonb,
  comments jsonb not null default '[]'::jsonb,
  author text not null default '我',
  likes int not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.miss_you (
  id text primary key,
  author text not null default '我',
  created_at timestamptz default now()
);

-- 2. 给 anon 角色授权（CloudBase 双层权限：GRANT + RLS）----------------------
grant select, insert, update, delete on public.anniversaries to anon;
grant select, insert, update, delete on public.schedules   to anon;
grant select, insert, update, delete on public.periods     to anon;
grant select, insert, update, delete on public.moments     to anon;
grant select, insert, update, delete on public.miss_you    to anon;

-- 3. 开启行级安全（RLS）并允许 anon 全量读写（情侣私密应用）--------------------
alter table public.anniversaries enable row level security;
alter table public.schedules     enable row level security;
alter table public.periods       enable row level security;
alter table public.moments       enable row level security;
alter table public.miss_you      enable row level security;

create policy "anon_all_anniversaries" on public.anniversaries
  for all to anon using (true) with check (true);

create policy "anon_all_schedules" on public.schedules
  for all to anon using (true) with check (true);

create policy "anon_all_periods" on public.periods
  for all to anon using (true) with check (true);

create policy "anon_all_moments" on public.moments
  for all to anon using (true) with check (true);

create policy "anon_all_miss_you" on public.miss_you
  for all to anon using (true) with check (true);

-- ============================================================================
-- 说明：
-- 1. 云存储（图片）在同一个环境里自带，不需要单独建桶；稍后在「云存储」页面
--    把权限设置为允许读写即可（我会在接入时告诉你怎么设）。
-- 2. 如果执行时报某条 policy 已存在，忽略即可（重复执行安全）。
-- ============================================================================
