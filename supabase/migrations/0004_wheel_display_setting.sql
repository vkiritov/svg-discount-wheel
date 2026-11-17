-- Persist the wheel presentation choice so only admins control the public wheel.
alter table public.store_settings
  add column if not exists wheel_display_mode text not null default 'new'
  check (wheel_display_mode in ('new','old'));
