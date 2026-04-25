# Game Development Principles

This document outlines mandatory features and design standards for all card games in the Casino Delight project (Minus, Matka, Tehri, etc.).

## Mandatory Features

### 1. Room Management
- **Quit Room Button**: Every game table must have a clearly visible "Quit Room" button in the Top HUD.
  - Clicking this button must prompt for confirmation.
  - Upon confirmation, the app must:
    1. Clear the local game session (player ID, room code).
    2. Redirect the user back to the Hub (`/`).
    
### 2. Session Management
- **Persistence**: All games must use `SharedPreferences` to persist the session (Room Code, Player ID, Name).
- **Auto-Restore**: On page refresh, the game screens must wait for the session to be restored before deciding to show joining UI or the table.

### 3. Aesthetics
- **Premium HUD**: Top HUD should use glassmorphism (BackdropFilter blur).
- **Table Design**: Use curated dark themes with gold/copper accents.

## Technical Standards
- **Schema Prefixes**: Tables and RPCs must be prefixed with the game name (e.g., `tehri_`, `matka_`).
- **Riverpod**: Use `StreamProvider` for real-time state and `StateNotifier` for session handling.
