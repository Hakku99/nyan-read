# Flutter Rules

This file ensures UI code stays consistent.

---

# Theme System

All UI must use centralized tokens.

Create:

NyanColors  
NyanTypography  
NyanSpacing  
NyanRadius  
NyanShadows  

Never hardcode UI values.

---

# Theme Extension

Use ThemeExtension.

Example access:

Theme.of(context).extension<NyanTheme>()

---

# Layout Rules

Spacing must use tokens.

Example:

SizedBox(height: NyanSpacing.space16)

Avoid random spacing numbers.

---

# Card Style

borderRadius: NyanRadius.card  
color: NyanColors.surface  

Use light shadows.

---

# Bottom Sheets

Top radius: NyanRadius.sheet

Structure:

header  
sections  
actions

---

# Reader Layout

Reader page structure:

Stack
ReaderContent
GestureLayer
ToolbarOverlay
SelectionOverlay

ReaderContent must be the base layer.

---

# Animations

Use simple transitions.

Fade  
Slide  
Opacity  
AnimatedContainer

Durations

160ms small  
220ms page  
260ms sheet  

Avoid bounce effects.

---

# Empty States

Use standard structure:

icon  
title  
description  
primary action  

---

# Tap Targets

Minimum size

44x44

---

# Naming

Use clear names.

Example:

BookshelfPage  
ReaderPage  
BookmarkCard  
HighlightCard  

Avoid generic widget names.

---

# Code Check

Before merging UI verify:

tokens used  
spacing consistent  
radius consistent  
theme works in light and dark