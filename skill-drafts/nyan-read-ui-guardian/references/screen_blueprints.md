# Screen Blueprints

This file defines the UI architecture system.

All screens must follow:

1. page category
2. layout template
3. component composition

---

# Page Categories

Every screen belongs to one category.

Reader Screen  
Library Screen  
Content List Screen  
Detail Screen  
Utility Screen  
Overlay Screen  
System Screen  
Experimental Screen

---

# Layout Templates

Choose one template per screen.

Centered Hero  
Header + Scroll  
Header + List  
Header + Grid  
Header + Mixed Shelf  
Full Content + Overlay  
Modal Sheet  
Dialog  
Split Layout (large screens)

---

# Category -> Template

System Screen  
Centered Hero

Reader Screen  
Full Content + Overlay

Library Screen  
Header + Mixed Shelf  
Header + Grid

Content List Screen  
Header + List

Detail Screen  
Header + Scroll

Utility Screen  
Header + List

Overlay Screen  
Modal Sheet  
Dialog

Experimental Screen  
Header + List

---

# Blueprint Logic

When creating a new screen:

1 identify category  
2 choose template  
3 compose with components  

Example:

Reading history  
-> Content List Screen  
-> Header + List  

Book detail  
-> Detail Screen  
-> Header + Scroll  

Reader page  
-> Reader Screen  
-> Full Content + Overlay

---

# Reader Layout

Reader must use:

content layer  
gesture layer  
overlay controls  
status line  

UI should disappear when inactive.

---

# Library Layout

Bookshelf must contain:

header  
continue reading section  
view controls  
book list or grid  

---

# List Screens

Rows must prioritize:

title  
context  
metadata

Scanning speed is more important than decoration.

---

# Detail Screens

Use sections or cards.

Avoid dense information walls.

---

# Overlay Screens

Use bottom sheet or dialog.

Controls must be grouped and short-lived.

---

# Expansion Rule

When adding new features:

Do NOT invent new layouts.

Fit the feature into:

Reader  
Library  
Content List  
Detail  
Utility  
Overlay