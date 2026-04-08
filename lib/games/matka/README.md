# Matka Game

## ⚠️ STANDING RULE: Full Independence

Every game in `lib/games/` is a **self-contained module**. This applies to Matka and every future game added to this hub:

- **No cross-game imports.** Matka code must not import anything from `lib/games/minus/` (or any other game folder). Likewise, Minus must not import from Matka.
- **Own models.** Each game defines its own `CardModel`, player models, and room models — even if they look similar. Do not share model classes across games.
- **Own providers.** Each game has its own Riverpod providers. No provider from one game is referenced by another.
- **Own services.** DB access, shuffle logic, and game actions are scoped entirely within the game's `services/` folder.
- **Own DB tables.** Each game uses its own Supabase schema (see `supabase/games/README.md`). Matka uses `matka.*` tables — never `public.rooms`, `public.players`, etc.
- **Shared infrastructure only.** The only shared code permitted is:
  - `lib/config/` — environment/Supabase init
  - `lib/router.dart` — route registration
  - `lib/screens/hub_screen.dart` — the game hub launcher

## Module Structure
```
lib/games/matka/
├── models/
│   ├── card_model.dart           ← Matka's own card definitions
│   └── matka_models.dart         ← MatkaRoom, MatkaPlayer, MatkaRound
├── providers/
│   └── matka_provider.dart       ← All Riverpod providers for Matka
├── services/
│   ├── matka_lobby_service.dart  ← create/join room
│   └── matka_game_service.dart   ← game actions (ante, deal, bet, reveal)
├── screens/
│   ├── home_screen.dart          ← Host/Join + Rules
│   ├── lobby_screen.dart         ← Waiting room
│   └── game_table_screen.dart    ← Main game UI
└── widgets/
    ├── playing_card.dart
    ├── pot_display.dart
    └── player_row.dart
```

## Supabase
- Matka DB tables use the **`matka` schema** (not `public`)
- Migrations live in `supabase/games/matka/`
