# RoomRally Style Guide

## Overview
RoomRally uses a modern **Dark Glassmorphism** aesthetic. The design relies heavily on translucent backgrounds, blurred backdrops, and a vibrant Blue/Indigo color palette with Orange accents.

## Core Theme

### Backgrounds
The global application background is a vertical gradient.
- **Class**: `bg-gradient-to-b from-blue-600 to-indigo-900`
- **Context**: Applied to the `<body>` or main container.

### Glassmorphism (Cards & Containers)
UI elements should look like floating glass panes.
- **Base**: `bg-white/10` (10% opacity white)
- **Backdrop**: `backdrop-blur-md` (Medium blur)
- **Border**: `border border-white/20` (Subtle white border)
- **Shadow**: `shadow-xl` or `shadow-2xl`
- **Rounded**: `rounded-3xl` (Large border radius)

**Example**:
```html
<div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 shadow-xl">
  Content...
</div>
```

## Typography

### Headings
- **Font**: Sans-serif (`font-sans`)
- **Weight**: Black (`font-black`)
- **Color**: White (`text-white`)
- **Spacing**: Tight tracking (`tracking-tighter`, `tracking-wide`)
- **Effects**: Drop shadows for depth (`drop-shadow-lg`)

### Body Text
- **Primary**: White (`text-white`)
- **Secondary/Muted**: Blue-200 (`text-blue-200`) - *Avoid slate-500 or gray on dark backgrounds.*

## Interactive Elements

### Primary Action Button (Orange)
Used for main calls to action (e.g., "Create Room", "Start Game").
- **Base**: `bg-orange-500`
- **Hover**: `hover:bg-orange-600`
- **Text**: `text-white font-black`
- **Shape**: `rounded-xl`
- **Effects**: `shadow-lg`, `active:scale-[0.98]`, `transform hover:scale-105`

**Example**:
```erb
<%= button_tag "Start Game", class: "bg-orange-500 hover:bg-orange-600 text-white font-black py-4 px-6 rounded-xl shadow-lg transform hover:scale-105 transition-all" %>
```

### Secondary Action Button (Blue)
Used for standard actions (e.g., "Join Room", "Save").
- **Base**: `bg-blue-600`
- **Hover**: `hover:bg-blue-700`
- **Text**: `text-white font-bold`

### Tertiary/Ghost Button
Used for less prominent actions (e.g., "Cancel", "Back").
- **Text**: `text-blue-200`
- **Hover**: `hover:text-white`
- **Background**: Transparent or very subtle (`hover:bg-white/5`)

## Icons
- Use **Lucide** icons.
- Colors should match text hierarchy (White or Blue-200).
- Example: `<%= lucide_icon('settings', class: "w-5 h-5 text-blue-200") %>`

## Do's and Don'ts

### ✅ Do
- Use `text-blue-200` for secondary text instead of gray.
- Use `backdrop-blur` to maintain readability on glass cards.
- Add `drop-shadow` to large white headings to pop against the background.
- Use uppercase and wide tracking (`uppercase tracking-widest`) for small labels.

### ❌ Don't
- **Avoid** opaque white backgrounds (`bg-white`) unless absolutely necessary (e.g., QR codes).
- **Avoid** legacy purple/pink gradients (`from-purple-500 to-pink-500`). Use the Blue/Indigo theme or specific Orange accents.
- **Avoid** standard gray text (`text-gray-500`) as it looks muddy on blue backgrounds.
