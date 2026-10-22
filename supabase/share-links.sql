-- "Add to Pax" from the iPhone share sheet. Run once in the Supabase SQL editor.
--
-- The Shortcut posts a row like this to /rest/v1/docs:
--   {"collection": "inbox", "data": {"url": "https://www.tiktok.com/...", "night": "tue", "by": "Prithvi"}}
-- night is a day name (Monday, tue, ...) or anything with "tin" in it to just keep it in the recipe tin.
-- This trigger files it onto the next one of that night (today counts) in New York time,
-- creating a placeholder week if Claude hasn't planned that week yet.

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
    insert into docs (path, collection, data) values ('box/' || key, 'box', card || jsonb_build_object('cuisine', 'New'))
      on conflict (path) do nothing;
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

  insert into docs (path, collection, data)
    values ('weeks/' || monday, 'weeks', jsonb_build_object('weekOf', monday::text, 'nights', '{}'::jsonb, 'note', '', 'stub', true))
    on conflict (path) do nothing;
  perform public.merge_doc('weeks/' || monday || '/nights/' || slot,
    jsonb_build_object('boxPick', card, 'flag', 'cook', 'by', who, 'at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')));
  new.data := new.data || jsonb_build_object('status', 'filed', 'filedTo', 'weeks/' || monday || '/nights/' || slot);
  return new;
end $$;

drop trigger if exists pax_file_shared_link on public.docs;
create trigger pax_file_shared_link before insert on public.docs
  for each row execute function public.pax_file_shared_link();
