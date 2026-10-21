# Pax

Prithvi and Nihal's weeknight dinners: the week on the fridge, who cooks each night, the recipe, a fridge full of groceries, and a recipe tin. One shared app on both phones; whatever one of you changes shows up on the other's within a second or two.

**App:** https://prithviguru.github.io/Pax/ (a PWA: open it in Safari, then Share → Add to Home Screen)

## What's here

- `docs/` - the app, served by GitHub Pages: `index.html`, `pax-db.js` (the shared-data layer), `config.js` (Supabase URL and public key), `sw.js`, `manifest.webmanifest`, icons and the paper-cutout art.
- `supabase/schema.sql` - the database: one `docs` table, a `members` list of the two emails allowed in, row-level security, live updates.
- `supabase/seed.sql` - everything from the old claude.ai version (the week of Oct 26, the recipe tin, staples, Monday handed to Prithvi).
- `tools/paxdb.py` - read and write the database from the command line; the planner uses it.
- `.claude/skills/pax-chef/SKILL.md` - the planner. It plans each week into Pax and answers "new options" requests.

## One-time setup

1. **Database.** In Supabase, open SQL Editor → New query. Paste `supabase/schema.sql`, put your two emails in the last lines, and run it. Then paste and run `supabase/seed.sql`.
2. **Sign-in codes.** Pax signs you in with a 6-digit code (email links open Safari instead of the installed app on iPhone). In Supabase → Authentication → Emails → **Magic Link**, set the body to:
   `<p>Your Pax code is <strong>{{ .Token }}</strong></p>`
3. **Hosting.** Make the repo public, then Settings → Pages → Build and deployment → Deploy from a branch → `main`, folder `/docs` → Save.
4. **Phones.** Open the app link in Safari, sign in with your email and the code, then Share → Add to Home Screen. Nihal does the same with his email.
5. **Planner access.** In the Claude environment settings, add `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as environment variables and allow the domain `xzvsxgbsdzwvdmgmclut.supabase.co`. The service role key is secret: it bypasses the two-email rule, so never paste it into chat or commit it.

## Shipping a change

Edit `docs/`, bump `CACHE` in `docs/sw.js`, merge to `main`. Pages redeploys in a minute or two; installed apps pick it up the next time they're opened online.

## How it works

- **Week (home):** the week as paper notes taped to the fridge. Every night is a cook night unless you tap "We're ordering in" or "We're eating out". Tap a note to open that night's recipe: swap to a backup, reject a dish (it never comes back), hand the night to the other cook, or save it to the recipe tin.
- **List:** a sage fridge. Pull the handle and the week's groceries sit on freezer, dairy, pantry and crisper-drawer shelves, with staples on the bottom "already have" shelf. Tap anything you've got. The list follows every swap and night out.
- **Recipes:** a recipe tin with divider tabs by cuisine, plus Quick and Never. Pull a card, flip it for the steps, or "Cook it this week" to drop it onto a night.
- **Planning:** Claude writes one `weeks/<Monday>` document per week: a pick and 2 backups for every cook night, nights out from Prithvi's calendar, and a `shelves` map for the fridge. See the skill for the shape.

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
