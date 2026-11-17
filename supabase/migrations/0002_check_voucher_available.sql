-- Public-safe voucher availability check.
-- Does not expose voucher rows; final redemption remains atomic in redeem_and_spin.
create or replace function public.check_voucher_available(p_code text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.vouchers
    where code = upper(trim(p_code))
      and used_at is null
  );
$$;

revoke all on function public.check_voucher_available(text) from public;
grant execute on function public.check_voucher_available(text) to anon, authenticated;
