# Tehri Game UI & Logic Optimizations

This document records critical solutions implemented to ensure a zero-lag, consistent gaming experience in Tehri. **Read this before starting any new feature development.**

## 1. Zero-Lag Card Play (Optimistic UI)
To prevent input lag where cards stay in hand for seconds after tapping:
- **Pattern**: Use "Optimistic Removal". The UI must remove the card from the hand *instantly* upon tap, before the server RPC even completes.
- **Provider Implementation**:
    - `tehriLocalPlayedCardsProvider`: Tracks cards the player has tapped in the current round.
    - `tehriPendingCardPlayProvider`: Tracks cards currently mid-network-request.
- **UI Logic**:
    - Filter the local hand against these sets: `visibleHand = hand.where((c) => !localPlayedCards.contains(c))`.
    - Handle `onTap` by updating the sets first, then firing `playCard`.
    - **Self-Correction**: If the RPC fails, remove the card from the sets to "rollback" and show it back in hand.

## 2. Flutter Web Hit-Testing Fix
Flutter Web (especially the HTML renderer) often has issues with `Transform.translate` hit areas. 
- **The Bug**: Using `Align` + `Transform.translate` to move cards into a fan layout causes the tap area to stay at the center-bottom, while the card *looks* like it's moved.
- **The Solution**: Use **`Positioned(left: ..., bottom: ...)`** for at-rest placement. 
- **Animation**: Only use `Transform.translate` for the *dynamic* part of the animation (e.g., sliding from off-screen). Once the animation controller reaches `1.0`, the transform offset should be `0`, leaving the card at its real layout position.

## 3. Anti-clockwise Consistency
All card games in this suite (Tehri, Minus) follow **anti-clockwise** rotation for dealing, bidding, and playing.
- **Dealing**: `(dealerIdx + 1 + i) % 4`.
- **Playing**: Next turn = `(currentTurnIdx - 1 + 4) % 4` (Wait, Check this! Usually anti-clockwise is +1 in indices if seats are 0..3 clockwise. If seats 0..3 are anti-clockwise, then +1 is correct. If seats are arranged clockwise, then moving anti-clockwise is -1).
- **Current project standard**: Seats are 0 (Bottom), 1 (Left), 2 (Top), 3 (Right) in **anti-clockwise order**. Thus, **adding 1** moves you anti-clockwise.

## 4. Double GestureDetector Conflicts
- Avoid wrapping a widget that already has a `GestureDetector` in another `GestureDetector`. This causes hit-test disputes.
- **Fix**: Pass the `onTap` callback down into the deepest widget that handles gestures (e.g., `PlayingCard`).

## 5. State Cleanup
- Always clear optimistic sets (`localPlayedCards`) at the start of a new round (status change to `cutting` or `bidding`).
