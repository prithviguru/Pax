# Pax

Prithvi and Nihal's shared weeknight dinners: who cooks each night, the recipe, swaps and rejects, a recipe box, and the week's ingredient list.

Live app: https://claude.ai/artifact/DWJiTaPkBHqrQmqNTWAe9Y (a Claude artifact backed by its own shared database).

## What's here

- `app/index.html` - the app page. Publish it with the Artifact tool to the URL above, with capabilities `{"db": {}, "user": {"scopes": ["profile"]}}`.
- `.claude/skills/pax-chef/SKILL.md` - the planner. It plans each week into the app and answers "new options" requests.
- `seed/` - the first week (Oct 26, 2026) and the starting staples list, as written into the database.

## How it works

- **Planning:** Claude writes one `weeks/<Monday>` document per week: a pick and 2 backups for every cook night, plus notes for nights out and travel.
- **Every pick counts as approved.** Either of you can swap to a backup, reject a dish (it never comes back), hand a night to the other cook, or mark a night as out or skip. Each night's changes live in `weeks/<Monday>/nights/<day>`.
- **Out of backups:** pull something from the recipe box, or ask Claude for 2 new options (saved in `requests`).
- **Ingredient list:** built live from the current picks, split into "Need to buy" and "Probably have" (anything on the staples list). Tick items off as you go.
- **History** lives in the database (`weeks`, `rejects`, `box`). It replaces Pippa's `/areas/meal-plan.md`.

## Sharing with Nihal

Open the app, then Share, and invite him by email as an **Editor**. Don't also turn on a public link. On a personal plan, that removes an outside Editor's ability to change anything.

## Database

| Path | Written by | What |
|---|---|---|
| `weeks/<YYYY-MM-DD>` | Claude | The week's plan (see the skill for the shape) |
| `weeks/<week>/nights/<mon..sun>` | The app | `current`, `rejected`, `boxPick`, `cook`, `flag`, `by`, `at` |
| `checks/<week>` | The app | `items: {<item-slug>: true}` |
| `rejects/<recipe-key>` | The app or Claude | Rejected dishes |
| `box/<recipe-key>` | The app | Recipe box |
| `staples/list` | The app | `items: [...]` |
| `requests/<id>` | The app, closed by Claude | `week`, `slot`, `note`, `status` |
