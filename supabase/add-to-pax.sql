-- A flat endpoint for the "Add to Pax" Shortcut, so it needs no nested dictionary:
--   POST /rest/v1/rpc/add_to_pax   {"url": "...", "night": "Thursday", "by": "Prithvi", "title": "Korean sesame broccoli"}
-- `title` is optional: what the dish is called. Leave it out and Claude names it from the caption.
-- Run once in the Supabase SQL editor, after share-links.sql. Safe to run again.

drop function if exists public.add_to_pax(text, text, text);

create or replace function public.add_to_pax(url text, night text default 'Recipe tin', "by" text default null, title text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare
  filed text;
begin
  insert into docs (collection, data)
  values ('inbox', jsonb_build_object('url', url, 'night', coalesce(night, 'Recipe tin'), 'by', "by", 'title', nullif(trim(coalesce(title, '')), '')))
  returning data ->> 'filedTo' into filed;
  return coalesce(filed, 'saved');
end $$;

grant execute on function public.add_to_pax(text, text, text, text) to anon, authenticated;
