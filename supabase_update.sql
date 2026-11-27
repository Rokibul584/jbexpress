-- =====================================================================
-- UPAZILA EXPRESS — Store / Stock / Review / Delete আপডেট
-- Supabase Dashboard → SQL Editor-এ পুরোটা পেস্ট করে একবার Run করুন।
-- বারবার Run করলেও সমস্যা নেই (idempotent)।
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) পণ্যের স্টক  (NULL = স্টক হিসাব করা হয় না / সবসময় আছে)
-- ---------------------------------------------------------------------
alter table public.provider_ads
  add column if not exists stock integer check (stock is null or stock >= 0);

-- ---------------------------------------------------------------------
-- 2) stores — প্রতিটি Provider-এর নিজস্ব দোকান
--    provider_id-এর type provider_accounts.id থেকে নিজে নিজে মিলিয়ে নেওয়া হয়
-- ---------------------------------------------------------------------
do $$
declare
  id_type text;
begin
  select format_type(a.atttypid, a.atttypmod) into id_type
  from pg_attribute a
  where a.attrelid = 'public.provider_accounts'::regclass
    and a.attname = 'id' and not a.attisdropped;

  if id_type is null then
    raise exception 'provider_accounts.id পাওয়া যায়নি';
  end if;

  execute format($f$
    create table if not exists public.stores (
      id          uuid primary key default gen_random_uuid(),
      provider_id %s not null unique references public.provider_accounts(id) on delete cascade,
      name        text not null check (char_length(name) between 2 and 100),
      description text,
      area        text,
      phone       text,
      logo_url    text,
      created_at  timestamptz not null default now(),
      updated_at  timestamptz not null default now()
    )$f$, id_type);
end $$;

alter table public.stores enable row level security;

drop policy if exists stores_public_read   on public.stores;
drop policy if exists stores_owner_insert  on public.stores;
drop policy if exists stores_owner_update  on public.stores;
drop policy if exists stores_owner_delete  on public.stores;
drop policy if exists stores_admin_all     on public.stores;

create policy stores_public_read on public.stores
  for select using (true);

create policy stores_owner_insert on public.stores
  for insert to authenticated
  with check (provider_id in (select id from public.provider_accounts where auth_user_id = auth.uid()));

create policy stores_owner_update on public.stores
  for update to authenticated
  using (provider_id in (select id from public.provider_accounts where auth_user_id = auth.uid()))
  with check (provider_id in (select id from public.provider_accounts where auth_user_id = auth.uid()));

create policy stores_owner_delete on public.stores
  for delete to authenticated
  using (provider_id in (select id from public.provider_accounts where auth_user_id = auth.uid()));

create policy stores_admin_all on public.stores
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 3) store_reviews — Customer-এর star + comment
-- ---------------------------------------------------------------------
create table if not exists public.store_reviews (
  id            uuid primary key default gen_random_uuid(),
  store_id      uuid not null references public.stores(id) on delete cascade,
  reviewer_name text not null check (char_length(btrim(reviewer_name)) between 1 and 60),
  rating        smallint not null check (rating between 1 and 5),
  comment       text check (comment is null or char_length(comment) <= 1000),
  created_at    timestamptz not null default now()
);
create index if not exists store_reviews_store_idx on public.store_reviews(store_id, created_at desc);

alter table public.store_reviews enable row level security;

drop policy if exists reviews_public_read   on public.store_reviews;
drop policy if exists reviews_public_insert on public.store_reviews;
drop policy if exists reviews_admin_delete  on public.store_reviews;

create policy reviews_public_read on public.store_reviews
  for select using (true);

create policy reviews_public_insert on public.store_reviews
  for insert to anon, authenticated
  with check (rating between 1 and 5);

create policy reviews_admin_delete on public.store_reviews
  for delete to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- 4) store_stats — গড় rating, review সংখ্যা, approved পণ্য সংখ্যা
-- ---------------------------------------------------------------------
create or replace view public.store_stats as
select
  s.id as store_id,
  (select count(*) from public.store_reviews r where r.store_id = s.id)                         as review_count,
  (select coalesce(round(avg(r.rating)::numeric, 1), 0) from public.store_reviews r where r.store_id = s.id) as avg_rating,
  (select count(*) from public.provider_ads a
     where a.provider_id = s.provider_id and a.status = 'approved')                              as ad_count
from public.stores s;

grant select on public.store_stats to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5) Provider / Admin নিজের বিজ্ঞাপন মুছতে পারবে
-- ---------------------------------------------------------------------
drop policy if exists provider_ads_owner_delete on public.provider_ads;
drop policy if exists provider_ads_admin_delete on public.provider_ads;

create policy provider_ads_owner_delete on public.provider_ads
  for delete to authenticated
  using (provider_id in (select id from public.provider_accounts where auth_user_id = auth.uid()));

create policy provider_ads_admin_delete on public.provider_ads
  for delete to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------
-- 6) Storage: ছবি মোছার অনুমতি (নিজের folder অথবা Admin)
--    Hosting storage খালি রাখার জন্য দরকার
-- ---------------------------------------------------------------------
drop policy if exists provider_ads_images_delete on storage.objects;
create policy provider_ads_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'provider-ads'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- ---------------------------------------------------------------------
-- 7) Admin: Delivered/Cancelled order সম্পূর্ণ মুছে ফেলা (order_items সহ)
--    id-এর type যা-ই হোক কাজ করবে
-- ---------------------------------------------------------------------
create or replace function public.admin_delete_orders(p_ids text[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not public.is_admin() then
    raise exception 'আপনার Admin অনুমতি নেই';
  end if;

  delete from public.order_items
   where order_id::text in (
     select id::text from public.customer_orders
      where id::text = any(p_ids) and status in ('delivered','cancelled'));

  delete from public.customer_orders
   where id::text = any(p_ids) and status in ('delivered','cancelled');

  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.admin_delete_orders(text[]) from public, anon;
grant execute on function public.admin_delete_orders(text[]) to authenticated;

-- ---------------------------------------------------------------------
-- 8) স্টক নিজে নিজে কমবে / স্টক না থাকলে অর্ডার আটকাবে
--    (order_items-এ provider_ad_id কলাম থাকলে তবেই চালু হয়)
-- ---------------------------------------------------------------------
create or replace function public.order_items_apply_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ok boolean;
begin
  if new.provider_ad_id is null then
    return new;
  end if;

  -- stock NULL হলে হিসাব রাখা হয় না
  if not exists (select 1 from public.provider_ads
                  where id::text = new.provider_ad_id::text and stock is not null) then
    return new;
  end if;

  update public.provider_ads
     set stock = stock - coalesce(new.quantity,1)
   where id::text = new.provider_ad_id::text
     and stock >= coalesce(new.quantity,1)
  returning true into ok;

  if ok is distinct from true then
    raise exception 'দুঃখিত, "%" এর পর্যাপ্ত স্টক নেই', coalesce(new.product_name,'পণ্য');
  end if;

  return new;
end $$;

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='order_items'
                and column_name='provider_ad_id') then
    drop trigger if exists trg_order_items_stock on public.order_items;
    create trigger trg_order_items_stock
      before insert on public.order_items
      for each row execute function public.order_items_apply_stock();
    raise notice 'স্টক trigger চালু হয়েছে।';
  else
    raise notice 'order_items-এ provider_ad_id কলাম নেই — স্টক নিজে নিজে কমবে না (বাকি সব কাজ করবে)।';
  end if;
end $$;
