# Pax

Prithvi and Nihal's weeknight dinners: the week on the fridge, who cooks each night, the recipe, a fridge full of groceries, and a recipe tin. One shared app on both phones; whatever one of you changes shows up on the other's within a second or two.

**App:** https://prithviguru.github.io/Pax/ (a PWA: open it in Safari, then Share → Add to Home Screen)

## What's here

- `docs/` - the app, served by GitHub Pages: `index.html`, `pax-db.js` (the shared-data layer), `config.js` (Supabase URL and public key), `sw.js`, `manifest.webmanifest`, icons and the paper-cutout art.
- `supabase/schema.sql` - the database: one `docs` table, a `members` list, live updates.
- `supabase/open-access.sql` - lets the app read and write without sign-in.
- `supabase/share-links.sql` - files links from the "Add to Pax" Shortcut onto a night or into the tin.
- `supabase/add-to-pax.sql` - the simple endpoint the Shortcut calls (`url`, `night`, `by`).
- `supabase/seed.sql` - everything from the old claude.ai version (the week of Oct 26, the recipe tin, staples, Monday handed to Prithvi).
- `tools/paxdb.py` - read and write the database from the command line; the planner uses it.
- `.claude/skills/pax-chef/SKILL.md` - the planner. It plans each week into Pax and answers "new options" requests.

## One-time setup

1. **Database.** In Supabase, open SQL Editor → New query. Run `supabase/schema.sql` (with your two emails in the last lines), then `supabase/seed.sql`, then `supabase/open-access.sql`. Run each in its own query.
2. **Hosting.** Make the repo public, then Settings → Pages → Build and deployment → Deploy from a branch → `main`, folder `/docs` → Save.
3. **Phones.** Open the app link in Safari, tap "I'm Prithvi" or "I'm Nihal", then Share → Add to Home Screen.
4. **Planner access.** In the Claude environment settings, set Network access to Custom and allow `xzvsxgbsdzwvdmgmclut.supabase.co`. The planner uses the same public key as the app, so no secret is needed.

There's no sign-in: each phone remembers whose it is ("Not you? Switch" in the footer changes it). Anyone with the link can read and change the plan, so don't post it anywhere public.

## Add to Pax from TikTok or Instagram

Run `supabase/share-links.sql` and then `supabase/add-to-pax.sql` once in the SQL editor. Then each of you builds this Shortcut on your iPhone (Shortcuts app → +):

1. Name it **Add to Pax**. Tap the (i) and turn on **Show in Share Sheet**. Under Share Sheet Types, keep only **URLs**.
2. Add **List** with these items: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Recipe tin.
3. Add **Choose from List**. Set the prompt to "Which night?"
3b. Add **Ask for Input**: type **Text**, prompt "What's it called?" (leave it blank when sharing and Claude names it from the caption).
4. Add **Get Contents of URL**:
   - URL: `https://xzvsxgbsdzwvdmgmclut.supabase.co/rest/v1/rpc/add_to_pax?apikey=sb_publishable_szxGiVMEmt200pw72wsJqw_f_h67yDp` (the key goes in the URL; a header in Shortcuts is easy to lose, and without it nothing saves)
   - Method: **POST**. No headers needed.
   - Request Body: **JSON** with four **Text** fields: `url` = **Shortcut Input**, `night` = **Selected Item** (called Chosen Item on some iOS versions), `by` = your name, `title` = **Provided Input**. No dictionary needed.
5. Add **Show Notification**: "Saved to Pax: Selected Item".

If a share doesn't show up, add **Quick Look** (Contents of URL) after Get Contents of URL and share again: it shows where the link was filed, or Supabase's error. In the app, Recipes → **Shared from your phones** lists everything that came through.

To use it: in TikTok tap Share → **More** (or in Instagram, Share → **Share to…**) → **Add to Pax** → pick a night. The recipe lands on the next one of that night (today counts, so on a Thursday "Friday" means tomorrow, even if Claude hasn't planned that week yet) and replaces whatever was planned there; the plan stays under Swap. "Recipe tin" keeps it in the tin under **New**. It saves under the name you typed. Claude reads the caption a few times a day and fills in the rest (ingredients, protein, carb, veg), and names it if you left the name blank.

## Shipping a change

Edit `docs/`, bump `CACHE` in `docs/sw.js`, merge to `main`. Pages redeploys in a minute or two; installed apps pick it up the next time they're opened online.

## How it works

- **Week (home):** the week as paper notes taped to the fridge. Every night is a cook night unless you tap "We're ordering in" or "We're eating out". Tap a note to open that night's recipe: swap to a backup, reject a dish (it never comes back), hand the night to the other cook, or save it to the recipe tin. The **pencil** next to the day edits what's on it: change the name and what goes in it (that goes on the grocery list), add a link or note, or clear the name to leave the night blank. "Go back to the plan" undoes it.
- **List:** a sage fridge. Pull the handle and the week's groceries sit on freezer, dairy, pantry and crisper-drawer shelves, with staples on the bottom "already have" shelf. Tap anything you've got. The list follows every swap and night out.
- **Recipes:** a recipe tin with divider tabs by cuisine, plus Quick and Never. Pull a card, flip it for the steps, or "Cook it this week" to drop it onto a night. **Add a recipe** under the tin takes a link and a name and puts it in the tin or on one of the next seven nights, same as the Shortcut; a card Claude hasn't filled in yet can be named from the tin.
- **Sunday picks:** Claude deals each of you about 10 dishes for the nights you cook. Swipe right to heart, left for not this week (or use the buttons); Never is a button so it can't happen by accident. Heart as many as you have nights, put them on your nights, done. Undo steps back a card at a time. Anything not picked by 9pm Sunday gets Claude's top picks. "Your Sunday picks" under the week's heading always gets you back in, to finish or to change your picks. The rest of your deck becomes that night's backups under Swap.
- **Planning:** Claude writes `weeks/<Monday>` (nights out, cook nights and who cooks, the `shelves` map) and `decks/<Monday>` (the cards) every Sunday. See the skill for the shape.

## Data

Every document is a row in `public.docs` keyed by a slash path:

| Path | Written by | What |
|---|---|---|
| `weeks/<YYYY-MM-DD>` | Claude | The week's plan |
| `weeks/<week>/nights/<mon..sun>` | The app | `current`, `rejected`, `boxPick`, `cook`, `flag` (order, out, cook), `by`, `at` |
| `checks/<week>` | The app | `items: {<item-slug>: true}` (ticked groceries) |
| `rejects/<recipe-key>` | The app or Claude | Rejected dishes |
| `box/<recipe-key>` | The app or Claude | Recipe tin cards |
| `staples/list` | The app | `items: [...]` (the fridge's bottom shelf) |
| `requests/<id>` | The app, closed by Claude | `week`, `slot`, `note`, `status` |
| `decks/<week>` | Claude | The Sunday deck: `deadline`, `lean` per night, and per person their cook `nights` and about 10 `cards` |
| `decks/<week>/picks/<person>` | The app | Progress through the deck: `pos`, `hearts`, `skipped`, `never`, then `done` and `slots` |
| `hauls/<id>` | Claude | Grocery orders read from DoorDash receipts: `store`, `date`, `items` with `name`, `shelf`, `keep` ("fridge" or "pantry") |
| `inbox/<id>` | The Shortcut | `url`, `night`, `by`; the database files it and adds `status`, `filedTo` |
