-- One-off, safe to run more than once:
-- 1. Puts the reel shared to "Friday" back on Friday Oct 23, if fix-friday-oct-23.sql moved it to Oct 30.
-- 2. Adds the pumpkin pasta (saved by browser Claude to the old claude.ai Pax) to the recipe tin.
do $$
declare n jsonb;
begin
  select data into n from docs where path = 'weeks/2026-10-26/nights/fri';
  if n -> 'boxPick' ->> 'id' like 'shared-%'
     and not exists (select 1 from docs where path = 'weeks/2026-10-19/nights/fri' and data -> 'boxPick' is not null) then
    perform merge_doc('weeks/2026-10-19/nights/fri', jsonb_build_object('boxPick', n -> 'boxPick', 'flag', 'cook', 'by', n -> 'boxPick' ->> 'savedBy'));
    perform merge_doc('weeks/2026-10-26/nights/fri', jsonb_build_object('boxPick', null) ||
      case when n ->> 'flag' = 'cook' then jsonb_build_object('flag', null) else '{}'::jsonb end);
  end if;
end $$;

insert into docs (path, collection, data) values ('box/www-instagram-com-p-ddegvacrmab', 'box', $pax${"at": "2026-10-22T00:00:00Z", "carb": "Rigatoni", "cuisine": "Italian", "dish": "Pumpkin Pasta with Sage Nut Crumble", "id": "box-www-instagram-com-p-ddegvacrmab", "ingredients": ["rigatoni", "pumpkin purée", "shallot", "tomato paste", "heavy cream", "parmesan", "butter", "vegetable bouillon", "garlic", "garlic powder", "red pepper flakes", "pecans", "walnuts", "fresh sage", "fresh thyme", "flaky salt", "olive oil"], "link": "https://www.instagram.com/p/DdeGvacRMab/", "minutes": 35, "protein": "Parmesan and nuts (weak, add white beans or burrata)", "source": "@softcoretable on Instagram", "veg": "Pumpkin, shallot", "tweak": "Serves 3. Use veggie bouillon. Light on protein: stir in a can of white beans or top with burrata. Full recipe is in the post caption."}$pax$::jsonb)
on conflict (path) do update set data = excluded.data;
