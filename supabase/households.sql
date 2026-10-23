-- Pax for more than one household: invite links, no passwords.
--
-- Before running: Supabase dashboard > Authentication > Sign In / Providers > turn on
-- "Allow anonymous sign-ins". Each phone signs itself in silently; opening an invite link joins
-- that phone to a household, and the database only ever shows a phone its own household's rows.
--
-- Run once in the SQL editor, after the earlier files. Safe to run again.
-- Everything already in the database becomes Prithvi & Nihal's household.

-- ---------- households and who's in them ----------
create table if not exists public.households (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  invite_code  text not null unique,   -- in the invite link: anyone with it can join
  share_token  text not null unique,   -- in the "Add to Pax" Shortcut
  created_at   timestamptz not null default now()
);
create table if not exists public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id      uuid not null unique,   -- one household per phone
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id)
);
alter table public.households enable row level security;
alter table public.household_members enable row level security;
-- No policies: phones only touch these through the functions below.

-- A random code from an unambiguous alphabet (no 0/o, 1/l/i). Built-ins only, up to 30 characters.
create or replace function public.pax_code(n int) returns text
language sql volatile as $$
  select left(string_agg(substr('abcdefghjkmnpqrstuvwxyz23456789', 1 + (get_byte(b, i) % 31), 1), '' order by i), n)
  from (select uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid()) b) x,
       generate_series(0, 31) i
  where i not in (6, 8, 22, 24);  -- the uuid version and variant bytes aren't random
$$;
-- The household of whoever is calling (null if this phone hasn't joined one).
create or replace function public.my_household() returns uuid
language sql stable security definer set search_path = public as $$
  select household_id from public.household_members where user_id = auth.uid();
$$;

-- Prithvi & Nihal's household, which owns everything that was here before.
insert into public.households (id, name, invite_code, share_token)
values ('00000000-0000-4000-8000-000000000001', 'Prithvi & Nihal', public.pax_code(10), public.pax_code(24))
on conflict (id) do nothing;

-- ---------- every document belongs to a household ----------
alter table public.docs add column if not exists household_id uuid references public.households (id) on delete cascade;
update public.docs set household_id = '00000000-0000-4000-8000-000000000001' where household_id is null;
alter table public.docs alter column household_id set default public.my_household();
alter table public.docs alter column household_id set not null;

do $$ begin
  if exists (select 1 from pg_constraint where conname = 'docs_pkey'
             and pg_get_constraintdef(oid) = 'PRIMARY KEY (path)') then
    alter table public.docs drop constraint docs_pkey;
    alter table public.docs add primary key (household_id, path);
  end if;
end $$;
drop index if exists public.docs_collection_idx;
create index if not exists docs_household_collection_idx on public.docs (household_id, collection);

-- Who's in the household, what they eat and like, and their usual week. The app writes it during
-- setup; the planner reads it. Prithvi & Nihal's comes from the planner skill.
insert into public.docs (household_id, path, collection, data) values
  ('00000000-0000-4000-8000-000000000001', 'household/profile', 'household', '{
     "name": "Prithvi & Nihal",
     "people": [
       {"key": "prithvi", "name": "Prithvi", "cooks": true, "diet": "Vegetarian"},
       {"key": "nihal", "name": "Nihal", "cooks": true, "diet": "No beef"}
     ],
     "week": {"mon": "nihal", "tue": "prithvi", "wed": "nihal", "thu": "prithvi"},
     "tasteInSkill": true
   }'::jsonb)
on conflict (household_id, path) do nothing;

-- ---------- access: your household only ----------
drop policy if exists "anyone reads docs" on public.docs;
drop policy if exists "anyone writes docs" on public.docs;
drop policy if exists "members read docs" on public.docs;
drop policy if exists "members write docs" on public.docs;
drop policy if exists "household reads docs" on public.docs;
drop policy if exists "household writes docs" on public.docs;
create policy "household reads docs"  on public.docs for select to authenticated using (household_id = public.my_household());
create policy "household writes docs" on public.docs for all    to authenticated using (household_id = public.my_household()) with check (household_id = public.my_household());
revoke all on public.docs from anon;
grant select, insert, update, delete on public.docs to authenticated;
-- The planner reads every household with the service key (it bypasses the policies above).
grant all on public.docs, public.households, public.household_members to service_role;

-- ---------- deep merge, now per household ----------
drop function if exists public.merge_doc(text, jsonb);
create or replace function public.merge_doc(p_path text, p_patch jsonb, p_household uuid default null) returns jsonb
language plpgsql security invoker set search_path = public as $$
declare v jsonb; h uuid := coalesce(p_household, public.my_household());
begin
  if h is null then raise exception 'not in a household'; end if;
  insert into public.docs (household_id, path, collection, data)
  values (h, p_path, regexp_replace(p_path, '/[^/]+$', ''), p_patch)
  on conflict (household_id, path) do update set data = public.jsonb_deep_merge(public.docs.data, excluded.data)
  returning data into v;
  return v;
end $$;
revoke execute on function public.merge_doc(text, jsonb, uuid) from anon;
grant execute on function public.merge_doc(text, jsonb, uuid) to authenticated, service_role;

-- ---------- joining, creating, sharing ----------
-- Start a household for this phone. Returns its id and invite code.
create or replace function public.create_household(p_name text, p_profile jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  delete from public.household_members where user_id = auth.uid();
  insert into public.households (name, invite_code, share_token)
  values (coalesce(nullif(trim(p_name), ''), 'Our household'), public.pax_code(10), public.pax_code(24))
  returning * into h;
  insert into public.household_members (household_id, user_id) values (h.id, auth.uid());
  insert into public.docs (household_id, path, collection, data)
  values (h.id, 'household/profile', 'household', coalesce(p_profile, '{}'::jsonb) || jsonb_build_object('name', h.name));
  return jsonb_build_object('id', h.id, 'name', h.name, 'invite_code', h.invite_code);
end $$;

-- Join with the code from an invite link. A phone in another household moves over.
create or replace function public.join_household(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  select * into h from public.households where invite_code = lower(trim(p_code));
  if h.id is null then raise exception 'That invite link has expired or is wrong. Ask for a new one.'; end if;
  delete from public.household_members where user_id = auth.uid() and household_id <> h.id;
  insert into public.household_members (household_id, user_id) values (h.id, auth.uid()) on conflict do nothing;
  return jsonb_build_object('id', h.id, 'name', h.name);
end $$;

-- This phone's household: name, invite code, Shortcut token, how many phones are in it.
create or replace function public.household_info() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', h.id, 'name', h.name, 'invite_code', h.invite_code, 'share_token', h.share_token,
           'phones', (select count(*) from public.household_members m where m.household_id = h.id))
  from public.households h where h.id = public.my_household();
$$;

-- Make a new invite link; the old one stops working. Phones already in stay in.
create or replace function public.new_invite_code() returns text
language plpgsql security definer set search_path = public as $$
declare c text := public.pax_code(10);
begin
  update public.households set invite_code = c where id = public.my_household();
  if not found then raise exception 'not in a household'; end if;
  return c;
end $$;

-- Leave the household on this phone (it can rejoin with a link).
create or replace function public.leave_household() returns void
language sql security definer set search_path = public as $$
  delete from public.household_members where user_id = auth.uid();
$$;

revoke execute on function public.create_household(text, jsonb), public.join_household(text), public.household_info(),
  public.new_invite_code(), public.leave_household(), public.my_household(), public.pax_code(int) from public, anon;
grant execute on function public.create_household(text, jsonb), public.join_household(text), public.household_info(),
  public.new_invite_code(), public.leave_household(), public.my_household() to authenticated;
grant execute on function public.my_household() to service_role;  -- merge_doc and the docs default call it

-- ---------- "Add to Pax" from the share sheet ----------
-- The Shortcut now sends its household's token: {"url", "night", "by", "title", "token"}.
-- Without a token it still files into Prithvi & Nihal's household, so their existing Shortcuts keep
-- working; once both have added the token, run: select public.pax_require_share_token();
create table if not exists public.pax_settings (key text primary key, value jsonb);
alter table public.pax_settings enable row level security;

create or replace function public.pax_require_share_token() returns void
language sql security definer set search_path = public as $$
  insert into public.pax_settings values ('require_share_token', 'true') on conflict (key) do update set value = 'true';
$$;
revoke execute on function public.pax_require_share_token() from public, anon, authenticated;

drop function if exists public.add_to_pax(text, text, text, text);
create or replace function public.add_to_pax(url text, night text default 'Recipe tin', "by" text default null,
                                             title text default null, token text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare
  h uuid;
  filed text;
begin
  if nullif(trim(coalesce(token, '')), '') is not null then
    select id into h from public.households where share_token = trim(token);
    if h is null then return 'That Shortcut token is wrong. Copy it again from Pax > Household.'; end if;
  elsif exists (select 1 from public.pax_settings where key = 'require_share_token' and value = 'true') then
    return 'Add your household token to the Shortcut. It''s in Pax > Household.';
  else
    h := '00000000-0000-4000-8000-000000000001';
  end if;
  insert into public.docs (household_id, collection, data)
  values (h, 'inbox', jsonb_build_object('url', url, 'night', coalesce(night, 'Recipe tin'), 'by', "by",
          'title', nullif(trim(coalesce(title, '')), '')))
  returning data ->> 'filedTo' into filed;
  return coalesce(filed, 'saved');
end $$;
grant execute on function public.add_to_pax(text, text, text, text, text) to anon, authenticated;

-- The trigger that files a shared link onto the right night (or the tin), within its household.
create or replace function public.pax_file_shared_link() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  url      text := nullif(trim(new.data ->> 'url'), '');
  night    text := lower(trim(coalesce(new.data ->> 'night', 'tin')));
  who      text := nullif(new.data ->> 'by', '');
  site     text;
  card     jsonb;
  key      text;
  today    date := (now() at time zone 'America/New_York')::date;
  want     int;
  target   date;
  monday   date;
  slot     text;
begin
  if new.collection is distinct from 'inbox' then return new; end if;
  if new.path is null then new.path := 'inbox/' || gen_random_uuid(); end if;
  if url is null then return new; end if;

  site := case when url ~* 'tiktok\.com' then 'TikTok' when url ~* 'instagram\.com' then 'Instagram' else 'the web' end;
  key  := left(regexp_replace(regexp_replace(lower(url), '^https?://', ''), '[^a-z0-9]+', '-', 'g'), 150);
  key  := regexp_replace(key, '(^-+|-+$)', '', 'g');
  card := jsonb_build_object(
    'dish', coalesce(nullif(new.data ->> 'title', ''), 'Recipe from ' || site),
    'link', url, 'source', site, 'pending', true, 'savedBy', who,
    'id', 'shared-' || left(key, 40));

  if night like '%tin%' or night = '' then
    insert into public.docs (household_id, path, collection, data)
    values (new.household_id, 'box/' || key, 'box', card || jsonb_build_object('cuisine', 'New'))
      on conflict (household_id, path) do nothing;
    new.data := new.data || jsonb_build_object('status', 'filed', 'filedTo', 'box/' || key);
    return new;
  end if;

  want := array_position(array['mon','tue','wed','thu','fri','sat','sun'], left(night, 3));
  if want is null then
    new.data := new.data || jsonb_build_object('status', 'unknown night'); return new;
  end if;
  target := today + ((want - extract(isodow from today)::int + 7) % 7);
  monday := target - (extract(isodow from target)::int - 1);
  slot   := (array['mon','tue','wed','thu','fri','sat','sun'])[want];

  perform public.merge_doc('weeks/' || monday || '/nights/' || slot,
    jsonb_build_object('boxPick', card, 'flag', 'cook', 'by', who, 'at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
    new.household_id);
  new.data := new.data || jsonb_build_object('status', 'filed', 'filedTo', 'weeks/' || monday || '/nights/' || slot);
  return new;
end $$;

drop trigger if exists pax_file_shared_link on public.docs;
create trigger pax_file_shared_link before insert on public.docs
  for each row execute function public.pax_file_shared_link();

-- Prithvi & Nihal's invite link code and Shortcut token, to copy into the app's setup.
select name, invite_code, share_token from public.households where id = '00000000-0000-4000-8000-000000000001';
