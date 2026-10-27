-- ============================================================================
-- CloudBase 增量迁移 v3：设备推送 ID + 想你发送者ID
-- 使用：控制台 → 数据库 → SQL 编辑器 → 执行（重复执行安全）
-- ============================================================================

-- 1. 用户档案增加极光 registrationId（用于定向推送，避免广播限流）
alter table public.profiles
  add column if not exists jpush_reg_id text not null default '';

-- 2. 想你记录增加发送者设备 ID（真正的用户区分）
alter table public.miss_you
  add column if not exists author_id text not null default '';
