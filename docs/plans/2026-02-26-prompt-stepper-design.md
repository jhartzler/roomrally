# Prompt Stepper Design — Comedy Clash Hand Screen

**Date:** 2026-02-26
**Context:** Players with 2 prompts in Comedy Clash (Write and Vote) didn't realize they had a second prompt because it was below the fold on mobile phones. The existing "Prompt 1 of 2" pill wasn't visually prominent enough.

## Problem

The active prompt form (card header + prompt text + textarea + submit button) is tall enough on mobile that the second collapsed prompt card is pushed below the fold. Players finish their first prompt and wait, not realizing they have another one to answer.

## Solution

Replace the "Prompt 1 of 2" progress pill with a horizontal 2-step stepper above the active form. The stepper shows both prompt texts (truncated) simultaneously, making it immediately clear there are two prompts.

## Layout

```
┌─────────────────────────────────────────────┐
│  Write your best answer...                  │
│                                             │
│  ┌──────────────────┐  ┌──────────────────┐ │
│  │ ① ACTIVE         │  │ ② UP NEXT        │ │
│  │ Write a caption  │  │ What would your  │ │
│  │ for this photo...│  │ mom say about...  │ │
│  └──────────────────┘  └──────────────────┘ │
│                                             │
│  [Timer if enabled]                         │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ [textarea]                              ││
│  │                                         ││
│  │ [Submit Response]                       ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

## Stepper States

| Step state | Visual treatment |
|---|---|
| Active (current) | Bright card, highlighted border, "ACTIVE" label |
| Pending / Up Next | Dimmed card, "UP NEXT" label |
| Submitted / Done | Dimmed card with green checkmark, "DONE" label |

## Changes to `_prompt_screen.html.erb`

1. Remove the existing "Round X • Prompt 1 of 2" progress pill.
2. Add a new horizontal 2-up stepper section above the timer — one card per prompt, side by side, each showing the numbered badge + truncated prompt text + state label.
3. The active form's "Active Prompt" header bar inside `_form.html.erb` can be removed (the stepper replaces its function and saves vertical space).

## Scope

- Comedy Clash always has exactly 2 prompts per player per round.
- The stepper is hardcoded for 2 — no need to generalize.
- No new Stimulus controllers needed; this is pure HTML/ERB/Tailwind.
- No changes to game logic, state machine, or controllers.
