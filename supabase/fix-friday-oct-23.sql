-- One-off: move the reel saved to Friday Oct 23 (an unplanned week) onto Friday Oct 30,
-- then remove the placeholder week it created. Safe to run more than once.
do $$
declare pick jsonb;
begin
  select data -> 'boxPick' into pick from docs where path = 'weeks/2026-10-19/nights/fri';
  if pick is not null then
    perform merge_doc('weeks/2026-10-26/nights/fri', jsonb_build_object('boxPick', pick, 'flag', 'cook', 'by', pick ->> 'savedBy'));
  end if;
  delete from docs where path like 'weeks/2026-10-19/nights/%';
  delete from docs where path = 'weeks/2026-10-19' and coalesce((data ->> 'stub')::boolean, false);
end $$;
