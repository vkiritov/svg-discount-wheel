-- Lucky Discount Wheel schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.store_settings (
  id integer primary key default 1 check (id = 1),
  shop_name text not null default 'LUCKY DISCOUNT WHEEL',
  wheel_title text not null default 'LUCKY DISCOUNT WHEEL',
  whatsapp_number text not null default '',
  wheel_mode text not null default 'probability' check (wheel_mode in ('probability','segments')),
  updated_at timestamptz not null default now()
);

insert into public.store_settings(id) values(1) on conflict(id) do nothing;

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  discount_percent numeric(5,2) not null check(discount_percent > 0 and discount_percent <= 100),
  probability numeric(7,4) not null default 0 check(probability >= 0),
  segments integer not null default 1 check(segments > 0),
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.rewards(label,discount_percent,probability,segments,sort_order)
select '5%',5,30,3,0 where not exists(select 1 from public.rewards);
insert into public.rewards(label,discount_percent,probability,segments,sort_order)
select '10%',10,30,3,1 where (select count(*) from public.rewards)=1;
insert into public.rewards(label,discount_percent,probability,segments,sort_order)
select '15%',15,30,3,2 where (select count(*) from public.rewards)=2;
insert into public.rewards(label,discount_percent,probability,segments,sort_order)
select '20%',20,10,1,3 where (select count(*) from public.rewards)=3;

create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.spins (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null unique references public.vouchers(id),
  voucher_code text not null,
  buyer_name text,
  reward_id uuid references public.rewards(id),
  reward_label text not null,
  discount_percent numeric(5,2) not null,
  created_at timestamptz not null default now()
);

create index if not exists spins_created_at_idx on public.spins(created_at desc);
create index if not exists vouchers_code_idx on public.vouchers(code);

create or replace function public.is_wheel_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select coalesce((auth.jwt()->'app_metadata'->>'role')='admin',false); $$;

alter table public.store_settings enable row level security;
alter table public.rewards enable row level security;
alter table public.vouchers enable row level security;
alter table public.spins enable row level security;

drop policy if exists "public read store settings" on public.store_settings;
create policy "public read store settings" on public.store_settings for select to anon,authenticated using(true);
drop policy if exists "admin manage store settings" on public.store_settings;
create policy "admin manage store settings" on public.store_settings for all to authenticated using(public.is_wheel_admin()) with check(public.is_wheel_admin());

drop policy if exists "public read enabled rewards" on public.rewards;
create policy "public read enabled rewards" on public.rewards for select to anon,authenticated using(enabled=true or public.is_wheel_admin());
drop policy if exists "admin manage rewards" on public.rewards;
create policy "admin manage rewards" on public.rewards for all to authenticated using(public.is_wheel_admin()) with check(public.is_wheel_admin());

drop policy if exists "admin manage vouchers" on public.vouchers;
create policy "admin manage vouchers" on public.vouchers for all to authenticated using(public.is_wheel_admin()) with check(public.is_wheel_admin());
drop policy if exists "admin read spins" on public.spins;
create policy "admin read spins" on public.spins for select to authenticated using(public.is_wheel_admin());

-- Atomic redemption: row lock + unique voucher_id prevent concurrent/repeated spins.
create or replace function public.redeem_and_spin(p_code text,p_buyer_name text default null)
returns table(spin_id uuid,voucher_code text,buyer_name text,reward_id uuid,reward_label text,discount_percent numeric,created_at timestamptz)
language plpgsql security definer set search_path=''
as $$
declare
  v_voucher public.vouchers%rowtype;
  v_settings public.store_settings%rowtype;
  v_reward public.rewards%rowtype;
  v_total numeric;
  v_pick numeric;
  v_acc numeric := 0;
  v_spin_id uuid;
begin
  select * into v_voucher from public.vouchers where code=upper(trim(p_code)) for update;
  if not found then raise exception 'Kode voucher tidak ditemukan.'; end if;
  if v_voucher.used_at is not null then raise exception 'Voucher sudah digunakan.'; end if;

  select * into v_settings from public.store_settings where id=1;
  if v_settings.wheel_mode='segments' then
    select sum(segments) into v_total from public.rewards where enabled;
  else
    select sum(probability) into v_total from public.rewards where enabled;
  end if;
  if coalesce(v_total,0)<=0 then raise exception 'Hadiah belum dikonfigurasi.'; end if;
  if v_settings.wheel_mode='probability' and abs(v_total-100)>0.0001 then
    raise exception 'Total peluang hadiah harus tepat 100%%.';
  end if;

  v_pick := random()*v_total;
  if v_settings.wheel_mode='segments' then
    for v_reward in select * from public.rewards where enabled order by sort_order loop
      v_acc := v_acc + v_reward.segments;
      if v_pick < v_acc then exit; end if;
    end loop;
  else
    for v_reward in select * from public.rewards where enabled order by sort_order loop
      v_acc := v_acc + v_reward.probability;
      if v_pick < v_acc then exit; end if;
    end loop;
  end if;
  if v_reward.id is null then raise exception 'Gagal memilih hadiah.'; end if;

  update public.vouchers set used_at=now() where id=v_voucher.id and used_at is null;
  if not found then raise exception 'Voucher sudah digunakan.'; end if;

  insert into public.spins(voucher_id,voucher_code,buyer_name,reward_id,reward_label,discount_percent)
  values(v_voucher.id,v_voucher.code,nullif(trim(p_buyer_name),''),v_reward.id,v_reward.label,v_reward.discount_percent)
  returning id into v_spin_id;

  return query select v_spin_id,v_voucher.code,nullif(trim(p_buyer_name),''),v_reward.id,v_reward.label,v_reward.discount_percent,now();
end;
$$;

revoke all on function public.redeem_and_spin(text,text) from public;
grant execute on function public.redeem_and_spin(text,text) to anon,authenticated;
grant select on public.store_settings,public.rewards to anon,authenticated;
grant select,insert,update,delete on public.store_settings,public.rewards to authenticated;
grant select,insert,update,delete on public.vouchers to authenticated;
grant select on public.spins to authenticated;
