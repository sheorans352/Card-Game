# Supabase — Game Database Structure

## ⚠️ STANDING RULE: Schema Isolation

**Every game owns its own Postgres schema.** This is a permanent architectural rule — not optional for any new game:

- Matka tables live in the `matka` schema. They are never accessed by Minus, and vice versa.
- Adding a new game means creating a new schema (`CREATE SCHEMA <game>;`) and placing all its tables there.
- Cross-schema foreign keys between games are **forbidden**.
- The `public` schema belongs exclusively to Minus (legacy; it was built before this convention).

## Schema Ownership

| Game     | Schema        | Tables |
|----------|---------------|--------|
| Minus    | `public`      | `rooms`, `players`, `hands`, `played_cards`, `round_results` |
| Matka    | `matka`       | `matka.rooms`, `matka.players`, `matka.rounds` |
| Tehri    | `tehri`       | TBD |
| 3 Patti  | `three_patti` | TBD |
| Poker    | `poker`       | TBD |

## Migrations Convention

- Historical Minus migrations → `supabase/migrations/` (flat, as created)
- New Minus migrations → `supabase/games/minus/` (prefixed with timestamp)
- Future game migrations → `supabase/games/<game>/` (prefixed with timestamp)

## RLS Policy Rule
Every table in every schema must have Row Level Security **enabled** and at least a permissive `SELECT` policy for anonymous/authenticated roles before going live.
