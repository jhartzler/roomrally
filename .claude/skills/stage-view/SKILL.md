---
name: stage-view
description: Use when creating or modifying _stage_*.html.erb partials, editing stage views, or touching any UI projected on the shared screen. Trigger on stage layout changes, stage styling, or broadcast target issues.
---

# Stage View Development Guard

Pre-flight checklist and post-edit validation for stage partials. Stage views are projected on shared screens (typically 1920x1080) and have strict constraints that are repeatedly violated.

## Pre-Flight: Read Before Every Stage Edit

### The 6 Constraints

1. **No scrolling on stage root.** The outer container is `fixed inset-0 overflow-hidden`. Content must fit within the viewport.

2. **Viewport-relative units only.** Use `text-vh-*` for text, `p-[Xvh]`/`gap-[Xvh]`/`mb-[Xvh]` for spacing. Never `px`, `rem`, or bare Tailwind spacing (`p-4`, `gap-2`).

3. **First child must be `<div id="stage_<status>">`**. The `stage-transition` Stimulus controller detects phase changes by watching this ID via MutationObserver. If the first child is a `<link>` tag or lacks an `id`, animations break silently.

4. **Animations only via `stage-transition` controller.** Don't add inline `animate-*` classes that replay on every broadcast morph. The controller only triggers animation when the first child's `id` changes (new phase), not on content updates within the same phase.

5. **Broadcast targets nested inside replacement containers.** `GameBroadcaster.broadcast_stage` replaces the `stage_content` container. Your partial is the replacement content. Don't reference targets outside of what you're rendering.

6. **Flex height with `min-h-0`.** Use `flex-1 min-h-0` on containers, `shrink-0` on fixed elements (headers, footers). Without `min-h-0`, flex children expand beyond the viewport.

### Layout Structure

```
fixed inset-0 overflow-hidden (viewport lock)
  └─ max-w-7xl mx-auto flex-1 min-h-0 flex flex-col (centering)
       └─ #stage_content flex-1 min-h-0 flex flex-col [data-controller="stage-transition"]
            └─ YOUR PARTIAL renders here
                 └─ <div id="stage_<status>" class="flex flex-col items-center ... flex-1">
```

### Text Size Reference

| Class | Use for |
|-------|---------|
| `text-vh-xs` / `text-vh-sm` | Labels, metadata |
| `text-vh-base` / `text-vh-lg` | Body text |
| `text-vh-xl` / `text-vh-2xl` | Player names, answers |
| `text-vh-3xl` / `text-vh-4xl` | Headings, questions |
| `text-vh-5xl` | Large titles |

Spacing: `p-[2vh]`, `mb-[3vh]`, `gap-[1vh]`, `h-[6vh]`, `w-[8vh]`

## Template

```erb
<div id="stage_<%= game.status %>" class="flex flex-col items-center justify-center flex-1">
  <%# Header — shrink-0 so it doesn't consume flex space %>
  <div class="shrink-0 mb-[2vh]">
    <span class="text-vh-2xl text-blue-200 font-bold uppercase tracking-widest">
      Phase Label
    </span>
  </div>

  <%# Main content — flex-1 to fill available space %>
  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-3xl p-[3vh] max-w-6xl w-full">
    <h2 class="text-vh-4xl font-black text-white leading-tight">
      <%= content %>
    </h2>
  </div>

  <%# Footer — shrink-0 %>
  <div class="mt-[3vh] shrink-0">
    <p class="text-vh-xl text-blue-200 font-semibold">Status message</p>
  </div>
</div>
```

## Post-Edit Validation

After modifying any stage partial, run these checks:

### Automated Checks

```bash
# 1. Check for px/rem sizing violations in stage partials
grep -rn 'class="[^"]*\b\(p-[0-9]\|m-[0-9]\|gap-[0-9]\|h-[0-9]\|w-[0-9]\|text-[0-9]\?xs\|text-sm\|text-base\|text-lg\|text-xl\|text-2xl\|text-3xl\|text-4xl\|text-5xl\)' app/views/games/*/_stage_*.html.erb

# 2. Check for scroll/overflow classes on stage containers
grep -rn 'overflow-y-auto\|overflow-x-auto\|overflow-scroll' app/views/games/*/_stage_*.html.erb

# 3. Verify first child has id="stage_*" (spot check)
head -3 app/views/games/<game>/_stage_<status>.html.erb
```

### Manual Checks

- [ ] First child is `<div id="stage_<status>">` (not `<link>`, not `<%= render %>`)
- [ ] No `px`/`rem` units for spacing or text sizing
- [ ] No `overflow-y-auto` on the stage root (OK on inner scrollable sections with `max-h-[60vh]`)
- [ ] No inline `animate-*` classes that would replay on morph
- [ ] `shrink-0` on header/footer elements
- [ ] `flex-1 min-h-0` on content containers that need to constrain children

### Screenshot Verification

For significant visual changes, capture a screenshot:

```bash
rake screenshots:capture
rake screenshots:report   # Opens side-by-side diff
```

Or write a quick ad-hoc screenshot spec (see CLAUDE.md "Ad-hoc Screenshots" section).

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `<link>` as first child | Animations never play | Move `<link>` below the `<div id="stage_*">` or remove |
| `p-4` instead of `p-[2vh]` | Fixed size doesn't scale | Use vh-based arbitrary values |
| `text-4xl` instead of `text-vh-4xl` | Text too small/large on projectors | Use `text-vh-*` custom classes |
| Missing `min-h-0` | Content overflows viewport | Add `min-h-0` alongside `flex-1` |
| `animate-fade-in` inline | Animation replays on every broadcast morph | Remove — `stage-transition` controller handles it |
| `overflow-y-auto` on root | Stage becomes scrollable | Move scroll to inner section with `max-h-[60vh]` |
| Missing `shrink-0` on headers | Header consumes flex space, content gets squished | Add `shrink-0` to fixed-height elements |

## When Scrolling IS Needed

Some phases (e.g., reviewing many answers) legitimately need scrollable content. The pattern:

```erb
<div id="stage_reviewing" class="flex flex-col items-center flex-1">
  <div class="shrink-0"><%# Header %></div>

  <%# Scrollable section — capped height, only this part scrolls %>
  <div class="w-full max-w-4xl max-h-[60vh] overflow-y-auto">
    <%# Long content here %>
  </div>

  <div class="shrink-0"><%# Footer %></div>
</div>
```

Never put `overflow-y-auto` on the stage root — only on inner sections with an explicit `max-h-[Xvh]` cap.
