-- Pax: shared dinners for Prithvi and Nihal.
-- Run once in the Supabase SQL editor (Project > SQL Editor > New query), then run seed.sql.
--
-- The app stores everything as JSON documents keyed by a slash path, the same shape it used
-- inside claude.ai: weeks/2026-10-26, weeks/2026-10-26/nights/mon, box/<recipe>, staples/list, ...

create table if not exists public.docs (
  path        text primary key,                 -- e.g. weeks/2026-10-26/nights/mon
  collection  text not null,                    -- the path minus its last segment
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);
create index if not exists docs_collection_idx on public.docs (collection);

-- Who may sign in and see the data. Add both of your emails here (see the end of this file).
create table if not exists public.members (
  email  text primary key,
  name   text not null
);

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members m where lower(m.email) = lower(auth.jwt() ->> 'email'));
$$;

alter table public.docs enable row level security;
alter table public.members enable row level security;

drop policy if exists "members read docs" on public.docs;
drop policy if exists "members write docs" on public.docs;
create policy "members read docs"  on public.docs for select using (public.is_member());
create policy "members write docs" on public.docs for all    using (public.is_member()) with check (public.is_member());

drop policy if exists "members read members" on public.members;
create policy "members read members" on public.members for select using (public.is_member());

-- Keep updated_at fresh.
create or replace function public.touch_doc() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := coalesce(auth.uid(), new.updated_by); return new; end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs for each row execute function public.touch_doc();

-- Deep-merge a patch into a document (creating it if missing). Used for ticking groceries,
-- so two phones ticking different items at once don't overwrite each other.
create or replace function public.jsonb_deep_merge(a jsonb, b jsonb) returns jsonb
language sql immutable as $$
  select case
    when jsonb_typeof(a) = 'object' and jsonb_typeof(b) = 'object' then (
      select coalesce(jsonb_object_agg(k,
        case when a ? k and b ? k then public.jsonb_deep_merge(a -> k, b -> k)
             when b ? k then b -> k else a -> k end), '{}'::jsonb)
      from (select jsonb_object_keys(a) k union select jsonb_object_keys(b)) keys)
    else b end;
$$;

create or replace function public.merge_doc(p_path text, p_patch jsonb) returns jsonb
language plpgsql security invoker set search_path = public as $$
declare v jsonb;
begin
  insert into public.docs (path, collection, data)
  values (p_path, regexp_replace(p_path, '/[^/]+$', ''), p_patch)
  on conflict (path) do update set data = public.jsonb_deep_merge(public.docs.data, excluded.data)
  returning data into v;
  return v;
end $$;

-- Live updates between phones.
alter table public.docs replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- ===== Edit these two lines with your real emails, then run. =====
insert into public.members (email, name) values
  ('PRITHVI_EMAIL_HERE', 'Prithvi'),
  ('NIHAL_EMAIL_HERE', 'Nihal')
on conflict (email) do update set name = excluded.name;
