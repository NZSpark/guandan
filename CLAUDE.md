# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development

```bash
pnpm install                  # Install dependencies (requires Node.js ≥ 24)
pnpm res:dev                  # ReScript compiler in watch mode (run in terminal 1)
pnpm dev                      # Vite dev server on port 3000 (run in terminal 2)
pnpm res:build                # One-shot ReScript compile
pnpm build                    # Production build (ReScript + Vite)
pnpm test                     # Run all tests (Vitest)
pnpm format                   # Format all ReScript files
```

Tests use Vitest with jsdom. Test files live in `tests/` with `_test.res` suffix. Single test: `pnpm test -- -t "test name"`.

## Architecture

**Stack**: ReScript 11 → React 19 via `@rescript/react`, built by Vite 7. All user-facing text is Simplified Chinese.

**Data model** (`src/Data/`, aggregated in `Data.res`):

```
Player                    → firstName, lastName, gender
Team                      → 2 players (player1Id/player2Id), club, initialScore
  ├─ Data_Level          → 掼蛋 13 levels (2…A), netSmallScore, cumulativeSmallScore
  ├─ Data_Match          → team1Id vs team2Id, levels → winner, fieldScore
  ├─ Data_Scoring        → win=3/draw=2/lose=1/absent=0/bye=3; 4-tier tiebreaks
  ├─ Data_Rounds         → array<array<Match.t>>
  ├─ Data_Pairing        → Blossom algorithm; avoid pairs, equal scores, upper vs lower
  ├─ Data_GroupStage     → Snake seeding + circle-method round-robin schedules
  ├─ Data_Knockout       → Seeded brackets (4/8/16 teams), club-clash avoidance
  └─ Data_Tournament     → Format (Swiss|GroupStage|Knockout), teamIds, tieBreaks, byeQueue
```

**Storage**: IndexedDB via localforage (`src/Db.res`). All data is local; JSON export/import and GitHub Gist backup available.

**Routing** (`src/Router.res`): URL-hash router — `#/` (splash), `#/tourneys`, `#/tourneys/:id`, `#/players`, `#/options`.

**Tournament view** (`src/PageTournament/PageTourney.res`): Tab-based with explicit variant `type tab = Status | Setup | Players | Round(int) | Scores(int)`. Inner component receives data from `LoadTournament.res` that computes rounds, standings, and completion state.

**Key scoring rule**: `docs/2026.pdf` — the official 南山杯 Aotearoa 掼蛋大赛指南 that governs all scoring and tiebreak logic.

## Code Conventions

- Use `open! Belt` (current convention; migration to `@rescript/core` planned).
- Warning errors: `+A-3-44-102` turned on; all pattern matches must be exhaustive (no `_` wildard for variant destructuring).
- Models have symmetric `encode`/`decode` functions for JSON serialization.
- ReScript output is ESM, in-source (`.res.mjs` suffix).
- Tests use the `TestData` and `DemoData` modules for fixtures; team names are Chinese (南山闪电, 雷霆战队, etc.).