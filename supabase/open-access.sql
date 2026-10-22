-- Pax without sign-in: the app asks "who's cooking?" and remembers it on each phone.
-- Run once in the Supabase SQL editor after schema.sql and seed.sql.
-- Anyone with the app's link can read and change the plan; the link is the only lock.

drop policy if exists "members read docs" on public.docs;
drop policy if exists "members write docs" on public.docs;
drop policy if exists "members read members" on public.members;
drop policy if exists "anyone reads docs" on public.docs;
drop policy if exists "anyone writes docs" on public.docs;
drop policy if exists "anyone reads members" on public.members;

create policy "anyone reads docs"    on public.docs    for select to anon, authenticated using (true);
create policy "anyone writes docs"   on public.docs    for all    to anon, authenticated using (true) with check (true);
create policy "anyone reads members" on public.members for select to anon, authenticated using (true);

grant select, insert, update, delete on public.docs to anon, authenticated;
grant select on public.members to anon, authenticated;
grant execute on function public.merge_doc(text, jsonb), public.jsonb_deep_merge(jsonb, jsonb) to anon, authenticated;
