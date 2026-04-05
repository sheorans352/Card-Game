# Matka Game

This folder will contain all Matka game code when development begins.

## Planned Structure
```
lib/games/matka/
  screens/
    home_screen.dart      ← Host/Join screen
    game_screen.dart      ← Matka game UI
  models/
    matka_models.dart
  providers/
    matka_provider.dart
  services/
    matka_service.dart
  widgets/
    ...
```

## Supabase
- Matka DB tables will use the **`matka` schema** (not `public`)
- Migrations live in `supabase/games/matka/`
