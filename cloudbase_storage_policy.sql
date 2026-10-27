-- ============================================================================
-- CloudBase PG 云存储权限策略：放行 anon 角色读/写
-- 使用：CloudBase 控制台 → 数据库 → SQL 编辑器 → 全部粘贴 → 执行
-- 说明：PG 模式云存储的权限只由 storage schema 上的 RLS Policy 决定（默认全拒）。
-- ============================================================================

-- 允许 anon 读取对象（下载 / 生成签名链接 / 列目录）
create policy "storage_anon_select" on storage.objects
  for select to anon using (true);

-- 允许 anon 上传（新建对象）
create policy "storage_anon_insert" on storage.objects
  for insert to anon with check (true);

-- 允许 anon 覆盖上传（upload upsert）
create policy "storage_anon_update" on storage.objects
  for update to anon using (true) with check (true);

-- 允许 anon 删除对象（可选；当前 App 不删图片，留着也无害）
create policy "storage_anon_delete" on storage.objects
  for delete to anon using (true);

-- 允许 anon 读取 bucket 元数据（SDK 上传前会校验 bucket 配置）
create policy "storage_anon_bucket_select" on storage.buckets
  for select to anon using (true);
