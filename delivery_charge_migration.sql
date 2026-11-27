-- UPAZILA EXPRESS: area-based rider delivery charge
-- Supabase SQL Editor-এ একবার Run করুন। Existing create_customer_order RPC পরিবর্তন করা হচ্ছে না।

create table if not exists public.area_delivery_charges (
  area_name text primary key check (char_length(btrim(area_name)) between 2 and 100),
  charge numeric(10,2) not null check (charge >= 0),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.area_delivery_charges enable row level security;
drop policy if exists area_delivery_charges_public_read on public.area_delivery_charges;
drop policy if exists area_delivery_charges_admin_all on public.area_delivery_charges;
create policy area_delivery_charges_public_read on public.area_delivery_charges
  for select to anon, authenticated using (is_active = true);
create policy area_delivery_charges_admin_all on public.area_delivery_charges
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.area_delivery_charges to anon, authenticated;
grant insert, update, delete on public.area_delivery_charges to authenticated;

-- Store charge separately from product subtotal. The existing order RPC continues to accept
-- its current argument list; this trigger derives the fee from the submitted area.
alter table public.customer_orders
  add column if not exists delivery_charge numeric(10,2) not null default 0,
  add column if not exists grand_total numeric(12,2) not null default 0;

create or replace function public.uex_apply_area_delivery_charge()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_charge numeric(10,2);
begin
  select charge into v_charge
  from public.area_delivery_charges
  where area_name = new.area and is_active = true;

  if v_charge is null then
    raise exception 'এই এলাকার Rider Charge নির্ধারণ করা হয়নি: %', coalesce(new.area, 'অজানা এলাকা');
  end if;

  new.delivery_charge := v_charge;
  new.grand_total := coalesce(new.total_amount, 0) + v_charge;
  return new;
end;
$$;

drop trigger if exists trg_uex_apply_area_delivery_charge on public.customer_orders;
create trigger trg_uex_apply_area_delivery_charge
before insert or update of area, total_amount on public.customer_orders
for each row execute function public.uex_apply_area_delivery_charge();

-- Existing order rows: grand_total initialized from current subtotal; no historical fee is guessed.
update public.customer_orders
set grand_total = coalesce(total_amount,0)
where grand_total = 0;

-- Add the initial area names here with the actual amounts chosen by the business owner.
-- Admin Panel > Delivery Charge can then manage amounts without editing SQL.

-- Ensure PostgREST sees the table and its policies immediately after migration.
grant usage on schema public to anon, authenticated;
notify pgrst, 'reload schema';
