# Pax

Prithvi and Nihal's shared weeknight dinners: who cooks each night, the recipe, swaps and rejects, a recipe box, and the week's ingredient list.

Live app: https://claude.ai/artifact/DWJiTaPkBHqrQmqNTWAe9Y (a Claude artifact backed by its own shared database).

## What's here

- `app/index.html` - the app page. Publish it with the Artifact tool to the URL above, with capabilities `{"db": {}, "user": {"scopes": ["profile"]}}`.
- `.claude/skills/pax-chef/SKILL.md` - the planner. It plans each week into the app and answers "new options" requests.
- `seed/` - the first week (Oct 26, 2026) and the starting staples list, as written into the database.
- `app/art/` - the paper-cutout tomato, peas and carrots, published alongside the page as `art/*.png`.

## How it works

- **Week (home):** the week as paper notes taped to the fridge. Every night is a cook night unless you tap "We're ordering in" or "We're eating out". Tap a note to open that night's recipe: swap to a backup, reject a dish (it never comes back), hand the night to the other cook, or save it to the recipe tin.
- **List:** a sage fridge. Pull the handle and the week's groceries sit on freezer, dairy, pantry and crisper-drawer shelves, with staples on the bottom "already have" shelf. Tap anything you've got. The list follows every swap and night out.
- **Recipes:** a recipe tin with divider tabs by cuisine, plus Quick and Never. Pull a card, flip it for the steps, or "Cook it this week" to drop it onto a night.
- **Planning:** Claude writes one `weeks/<Monday>` document per week: a pick and 2 backups for every cook night, nights out from Prithvi's calendar, and a `shelves` map for the fridge. See the skill for the shape.
- **History** lives in the database (`weeks`, `rejects`, `box`).

## Sharing with Nihal

Open the app, then Share, and invite him by email as an **Editor**. Don't also turn on a public link. On a personal plan, that removes an outside Editor's ability to change anything.

## Database

| Path | Written by | What |
|---|---|---|
| `weeks/<YYYY-MM-DD>` | Claude | The week's plan (see the skill for the shape) |
| `weeks/<week>/nights/<mon..sun>` | The app | `current`, `rejected`, `boxPick`, `cook`, `flag` (order, out, cook), `by`, `at` |
| `checks/<week>` | The app | `items: {<item-slug>: true}` |
| `rejects/<recipe-key>` | The app or Claude | Rejected dishes |
| `box/<recipe-key>` | The app or Claude | Recipe tin cards |
| `staples/list` | The app | `items: [...]` (the fridge's bottom shelf) |
| `requests/<id>` | The app, closed by Claude | `week`, `slot`, `note`, `status` |
