# Implement Time-Based Scoring for Think Fast (Speed Trivia) Game

## Overview

Add a speed trivia game mode ("Think Fast") where players earn points based on both correctness and response speed. Faster correct answers earn more points.

**Game model name**: Speed Trivia  
**Display name**: Think Fast

## Scoring Requirements

- **Correct answers**: Points decay linearly from 1000 (instant) to 500 (at time limit)
- **Formula**: `points = 1000 * (1 - (elapsed_seconds / time_limit) * 0.5)`
- **Minimum points**: 100 for any correct answer (floor, not the formula minimum)
- **Incorrect answers**: 0 points

## Round Lifecycle

1. **Round starts**: Record `started_at` timestamp when question is revealed to players
2. **Round closes**: Judge manually advances to next round, setting `closed_at`
3. **Grace period**: Continue accepting answers for 0.5 seconds after `closed_at` — these still count and receive (low) points based on the timing formula

## Key Implementation Details

- Use `Time.current` for elapsed time calculation, not `created_at` in before_create hooks
- Timing is server-authoritative (no client timestamps needed since this is an in-person game on shared network)
- If a player sees their answer submission succeed, it should count for points — never show a successful submission that then scores zero due to timing

## UX Philosophy

Be generous with edge cases. This is a party game. A player squeaking in at the deadline with 112 points isn't going to flip the leaderboard, but rejecting their answer after they saw it go through feels like a bug.

## Out of Scope

- Automatic round closing based on time limit (judge controls pacing manually)
- Client-side latency compensation
