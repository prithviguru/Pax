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

1. **Database.** In Supabase, open SQL Editor → New query and run, each in its own query: `supabase/schema.sql`, `supabase/seed.sql`, `supabase/open-access.sql`, `supabase/share-links.sql`, `supabase/add-to-pax.sql`, then `supabase/households.sql`.
2. **Sign-in.** Authentication → Sign In / Providers → turn on **Allow anonymous sign-ins** (do this before running `households.sql`).
3. **Hosting.** Make the repo public, then Settings → Pages → Build and deployment → Deploy from a branch → `main`, folder `/docs` → Save.
4. **Planner access.** In the Claude environment settings: Network access → Custom, allow `xzvsxgbsdzwvdmgmclut.supabase.co`; and add a secret environment variable `SUPABASE_SERVICE_ROLE_KEY` with the project's service role (secret) key from Supabase → Project Settings → API Keys. It never goes in the repo.

## Households and invite links

Pax is for a few households, each walled off from the others. There are no passwords:

- Each phone signs itself in anonymously the first time it opens Pax.
- **Start a household** on the welcome screen: who's eating (and what they can't eat), what you like, and who usually cooks which night. You then get an **invite link** to send the rest of the household; opening it on a phone puts that phone in. Within the household you just tap your name.
- **Household** (in the footer of the week) shows who's in it, the invite link, **Make a new link** (the old one stops working; phones already in stay in), the Shortcut token, and **Leave this household**.
- A new phone, or clearing Safari's data, means opening the invite link again.
- Everything from before households is Prithvi & Nihal's household. `households.sql` prints its invite code and Shortcut token at the end.

## Add to Pax from TikTok or Instagram

Each person builds this Shortcut on their iPhone (Shortcuts app → +):

1. Name it **Add to Pax**. Tap the (i) and turn on **Show in Share Sheet**. Under Share Sheet Types, keep only **URLs**.
2. Add **List** with these items: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Recipe tin.
3. Add **Choose from List**. Set the prompt to "Which night?"
3b. Add **Ask for Input**: type **Text**, prompt "What's it called?" (leave it blank when sharing and Claude names it from the caption).
4. Add **Get Contents of URL**:
   - URL: `https://xzvsxgbsdzwvdmgmclut.supabase.co/rest/v1/rpc/add_to_pax?apikey=sb_publishable_szxGiVMEmt200pw72wsJqw_f_h67yDp` (the key goes in the URL; a header in Shortcuts is easy to lose, and without it nothing saves)
   - Method: **POST**. No headers needed.
   - Request Body: **JSON** with five **Text** fields: `url` = **Shortcut Input**, `night` = **Selected Item** (called Chosen Item on some iOS versions), `by` = your name, `title` = **Provided Input**, `token` = your household's token from Pax → Household. No dictionary needed.
5. Add **Show Notification**: "Saved to Pax: Selected Item".

If a share doesn't show up, add **Quick Look** (Contents of URL) after Get Contents of URL and share again: it shows where the link was filed, or Supabase's error. In the app, Recipe tin → **Shared from your phones** lists everything that came through.

To use it: in TikTok tap Share → **More** (or in Instagram, Share → **Share to…**) → **Add to Pax** → pick a night. The recipe lands on the next one of that night (today counts, so on a Thursday "Friday" means tomorrow, even if Claude hasn't planned that week yet) and replaces whatever was planned there; the plan stays under Swap. "Recipe tin" keeps it in the tin under **New**. It saves under the name you typed. Claude reads the caption a few times a day and fills in the rest (ingredients, protein, carb, veg), and names it if you left the name blank.

## Shipping a change

Edit `docs/`, bump `CACHE` in `docs/sw.js`, merge to `main`. Pages redeploys in a minute or two; installed apps pick it up the next time they're opened online.

## How it works

The tab bar along the bottom has **Week**, **Fridge** and **Recipe tin**.

- **Week (home):** the week, one tile per cook night (with the recipe's photo, or a paper cutout from `docs/illustrations/` matched to the dish) and a plain row for each night out or ordering in. Tap a night to open it full screen and set it to Cooking, Ordering in or Eating out. From there: swap to a backup, reject a dish (it never comes back), hand the night to the other cook, or save it to the recipe tin. **Make my own** opens a blank form to put whatever you're making on the night. The **pencil** on the photo edits what's already on it: change the name and what goes in it (that goes on the grocery list), add a link or note, or clear the name to leave the night blank. "Go back to the plan" undoes it.
- **Fridge:** the week's groceries on freezer, dairy, pantry and crisper-drawer shelves, with staples in the door ("already have"). Things from a recent DoorDash order show as already in. Tap anything you've got. The list follows every swap and night out.
- **Recipe tin:** a photo grid with filters by cuisine, plus Quick and Never. Open a card for the details, or "Cook it this week" to drop it onto a night. **Add** takes a link and a name and puts it in the tin or on one of the next seven nights, same as the Shortcut; a card Claude hasn't filled in yet can be named from the tin.
- **Picks (the deck):** Claude keeps a deck dealt for each of the next four weeks, about 10 dishes per person for the nights they cook. Scroll to any of those weeks and its Pick button opens that week's deck, whenever you like. Swipe right to heart, left for not this week (or use the buttons); Never is a button so it can't happen by accident. Heart as many as you have nights, put them on your nights, and the done screen offers the next week's deck. Undo steps back a card at a time. Sunday evening is only a reminder if next week isn't picked yet; anything still not picked by 9pm that Sunday gets Claude's top picks. The rest of your deck becomes that night's backups under Swap.
- **Planning:** Claude writes `weeks/<Monday>` (nights out, cook nights and who cooks, the `shelves` map) and `decks/<Monday>` (the cards) every Sunday. See the skill for the shape.

## Data

Recipe cards carry an optional `image` (the recipe page's `og:image`); without one, the app shows a coloured tile with a paper cutout.

Every document is a row in `public.docs` keyed by its household and a slash path (`households` and `household_members` say who's in which):

| Path | Written by | What |
|---|---|---|
| `household/profile` | Setup in the app | `name`, `people` (`key`, `name`, `cooks`, `diet`), `taste` (`cuisines`, `spice`, `loves`, `avoid`), `week` (night → who usually cooks) |
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
