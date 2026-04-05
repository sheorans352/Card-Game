# Supabase — Game Database Structure

## Schema Ownership

Each game owns its own Postgres schema for full isolation.

| Game  | Schema   | Tables |
|-------|----------|--------|
| Minus | `public` | `rooms`, `players`, `hands`, `played_cards`, `round_results` |
| Matka | `matka`  | TBD |
| Tehri | `tehri`  | TBD |
| 3 Patti | `three_patti` | TBD |
| Poker | `poker`  | TBD |

## Migrations Convention

- Historical Minus migrations → `supabase/migrations/` (flat, as created)
- New Minus migrations → `supabase/games/minus/` (prefix with timestamp)
- Future game migrations → `supabase/games/<game>/` (prefix with timestamp)
