# Design System Specification
**TODO Planner & Task Management App**

---

## Design Philosophy

**Target Audience**: Professionals aged 30-45  
**Design Style**: Minimalistic, Professional, Clean, Trustworthy  
**Inspiration**: Todoist, Asana, Microsoft To-Do (enterprise aesthetics)

### Core Principles
1. **Clarity over decoration** – Every element serves a purpose
2. **Consistency** – Unified patterns across all screens
3. **Accessibility** – WCAG 2.1 AA compliant (contrast ratios, touch targets)
4. **Responsiveness** – Adapts to all device sizes (phones, tablets)

---

## Color Palette

### Light Mode
```
PRIMARY (Blue-Based Professional)
├─ Primary        : #2563EB (Blue 600) – Buttons, active states
├─ Primary Light  : #DBEAFE (Blue 100) – Hover backgrounds
├─ Primary Dark   : #1E40AF (Blue 800) – Pressed states

NEUTRALS
├─ Background     : #FFFFFF (White) – Main background
├─ Surface        : #F9FAFB (Gray 50) – Cards, containers
├─ Border         : #E5E7EB (Gray 200) – Dividers, borders
├─ Text Primary   : #111827 (Gray 900) – Headings, body text
├─ Text Secondary : #6B7280 (Gray 500) – Captions, metadata

SEMANTIC COLORS
├─ Success        : #10B981 (Green 500) – Completed tasks
├─ Warning        : #F59E0B (Amber 500) – Upcoming deadlines
├─ Error          : #EF4444 (Red 500) – Overdue, destructive actions
├─ Info           : #3B82F6 (Blue 500) – Informational notices
```

### Dark Mode
```
PRIMARY (Blue-Based Professional)
├─ Primary        : #3B82F6 (Blue 500) – Buttons, active states
├─ Primary Light  : #1E3A8A (Blue 900) – Hover backgrounds
├─ Primary Dark   : #60A5FA (Blue 400) – Pressed states

NEUTRALS
├─ Background     : #0F172A (Slate 900) – Main background
├─ Surface        : #1E293B (Slate 800) – Cards, containers
├─ Border         : #334155 (Slate 700) – Dividers, borders
├─ Text Primary   : #F1F5F9 (Slate 100) – Headings, body text
├─ Text Secondary : #94A3B8 (Slate 400) – Captions, metadata

SEMANTIC COLORS
├─ Success        : #34D399 (Green 400) – Completed tasks
├─ Warning        : #FBBF24 (Amber 400) – Upcoming deadlines
├─ Error          : #F87171 (Red 400) – Overdue, destructive actions
├─ Info           : #60A5FA (Blue 400) – Informational notices
```

---

## Typography

### Font Family
**Primary Font**: **'Inter'** (Google Fonts)  
**Fallback**: System UI fonts (`-apple-system, Roboto, sans-serif`)

### Type Scale (Mobile)
```
HEADINGS
├─ H1 (Page Titles)       : 28px / Bold / Line-height 1.2
├─ H2 (Section Headers)   : 22px / SemiBold / Line-height 1.3
├─ H3 (Card Titles)       : 18px / SemiBold / Line-height 1.4

BODY TEXT
├─ Body Large             : 16px / Regular / Line-height 1.5
├─ Body                   : 14px / Regular / Line-height 1.5
├─ Body Small (Captions)  : 12px / Regular / Line-height 1.4

BUTTONS & LABELS
├─ Button Text            : 15px / SemiBold / Line-height 1.4
├─ Label                  : 13px / Medium / Line-height 1.3
├─ Overline (ALL CAPS)    : 11px / SemiBold / Letter-spacing 0.5px
```

### Font Weights
- Regular: 400
- Medium: 500
- SemiBold: 600
- Bold: 700

---

## Spacing System

Use **4px base unit** for consistent rhythm.

```
SPACING SCALE
├─ 4px   (xs)  – Icon padding, tight gaps
├─ 8px   (sm)  – Compact spacing (list items)
├─ 12px  (md)  – Default element spacing
├─ 16px  (lg)  – Card padding, section spacing
├─ 24px  (xl)  – Screen padding, large gaps
├─ 32px  (2xl) – Major section separation
├─ 48px  (3xl) – Screen top/bottom margins
```

### Layout Padding
- **Screen edges**: 16px (mobile), 24px (tablet)
- **Card padding**: 16px
- **List item vertical**: 12px
- **Button padding**: 12px horizontal, 10px vertical

---

## Component Library

### 1. Buttons

#### Primary Button
```
STYLE
├─ Background : Primary color
├─ Text       : White
├─ Border     : None
├─ Radius     : 8px
├─ Height     : 48px (mobile)
├─ Padding    : 16px horizontal

STATES
├─ Default  : bg-primary, shadow-sm
├─ Hover    : bg-primary-dark, shadow-md
├─ Pressed  : bg-primary-dark, scale-95
├─ Disabled : bg-gray-200, text-gray-400, opacity-50
```

#### Secondary Button (Outline)
```
STYLE
├─ Background : Transparent
├─ Text       : Primary color
├─ Border     : 1.5px solid Primary color
├─ Radius     : 8px
├─ Height     : 48px

STATES
├─ Hover    : bg-primary-light
├─ Pressed  : bg-primary-light, border-primary-dark
```

#### Icon Button
```
STYLE
├─ Size     : 40x40px
├─ Radius   : 50% (circular)
├─ Icon     : 20px, Primary color

STATES
├─ Hover    : bg-gray-100 (light mode), bg-slate-700 (dark)
```

---

### 2. Cards

#### Standard Card
```
STYLE
├─ Background : Surface color
├─ Border     : 1px solid Border color
├─ Radius     : 12px
├─ Padding    : 16px
├─ Shadow     : 0 1px 3px rgba(0,0,0,0.1) (light mode only)

USAGE
├─ Task cards, Team member cards, Dashboard widgets
```

#### Elevated Card (Important/Active)
```
STYLE
├─ Background : Surface color
├─ Border     : None
├─ Radius     : 12px
├─ Shadow     : 0 4px 12px rgba(0,0,0,0.08)

USAGE
├─ Active task, Featured actions
```

---

### 3. Input Fields

#### Text Input
```
STYLE
├─ Background : Surface color
├─ Border     : 1.5px solid Border color
├─ Radius     : 8px
├─ Height     : 48px
├─ Padding    : 12px horizontal
├─ Text       : Body size, Text Primary color

STATES
├─ Default  : border-gray-200
├─ Focused  : border-primary, ring-4px-primary-light
├─ Error    : border-error, ring-4px-red-light
├─ Disabled : bg-gray-100, text-gray-400
```

#### Textarea
```
STYLE
├─ Min Height : 120px
├─ Padding    : 12px
├─ Resize     : Vertical only
```

---

### 4. Status Badges

#### Task Status
```
ONGOING
├─ Background : Info color (10% opacity)
├─ Text       : Info color (dark variant)
├─ Icon       : Clock icon

COMPLETED
├─ Background : Success color (10% opacity)
├─ Text       : Success color (dark variant)
├─ Icon       : Checkmark icon

OVERDUE
├─ Background : Error color (10% opacity)
├─ Text       : Error color (dark variant)
├─ Icon       : Alert icon

CANCELLED
├─ Background : Gray 200
├─ Text       : Gray 600
├─ Icon       : X icon

STYLE
├─ Radius     : 16px (pill-shaped)
├─ Padding    : 4px 10px
├─ Font Size  : 12px / SemiBold
```

---

### 5. Navigation

#### Bottom Navigation Bar (Mobile)
```
STYLE
├─ Background : Surface color
├─ Height     : 64px
├─ Border Top : 1px solid Border color
├─ Shadow     : 0 -2px 8px rgba(0,0,0,0.05)

ITEMS
├─ Count      : 4 items max
├─ Icon Size  : 24px
├─ Label      : 11px, below icon

STATES
├─ Active   : Icon & text in Primary color, bold
├─ Inactive : Icon & text in Text Secondary color
```

#### App Bar (Top)
```
STYLE
├─ Background : Surface color
├─ Height     : 56px
├─ Padding    : 16px horizontal
├─ Shadow     : 0 1px 3px rgba(0,0,0,0.05)

ELEMENTS
├─ Left       : Back button (24px icon) or Menu
├─ Center     : Page title (H3)
├─ Right      : Action icons (24px, max 2)
```

---

### 6. Lists

#### Task List Item
```
STRUCTURE
├─ Container  : Card with 12px vertical padding
├─ Layout     : Left icon (24px) + Content + Right chevron

CONTENT
├─ Title      : Body Large, Text Primary, 1 line max (ellipsis)
├─ Subtitle   : Body Small, Text Secondary, 1 line max
├─ Metadata   : Deadline + Assignee (Row, 12px spacing)

SPACING
├─ Icon-Text  : 12px gap
├─ Title-Subtitle : 4px gap
├─ Subtitle-Metadata : 6px gap

STATES
├─ Default  : bg-surface
├─ Pressed  : bg-gray-100 (light), bg-slate-700 (dark)
```

---

### 7. Modals & Bottom Sheets

#### Bottom Sheet
```
STYLE
├─ Background : Surface color
├─ Radius     : 16px top corners only
├─ Padding    : 24px
├─ Handle     : 32px wide × 4px tall, Gray 300, centered at top

USAGE
├─ Task details, Filters, Quick actions
```

#### Full-Screen Modal
```
STYLE
├─ Background : Background color
├─ Animation  : Slide up from bottom

USAGE
├─ Create task, Edit profile, Calendar view
```

---

### 8. Icons

**Icon Library**: Material Icons (Flutter default) or Lucide Icons  
**Sizes**: 16px (small), 20px (medium), 24px (default), 32px (large)  
**Style**: Outlined (not filled) for consistency

**Common Icons**:
```
Navigation    : chevron-right, chevron-left, arrow-back
Actions       : add, edit, delete, more-vert
Status        : check-circle, alert-circle, clock, x-circle
Social        : notifications, person, group, calendar
```

---

## Animations & Transitions

### Standard Durations
```
├─ Fast       : 150ms – Hover effects, ripples
├─ Standard   : 250ms – Page transitions, modals
├─ Slow       : 350ms – Drawer open/close
```

### Easing Curves
```
├─ Default    : Cubic Bezier (0.4, 0.0, 0.2, 1) – Material standard
├─ Enter      : Cubic Bezier (0.0, 0.0, 0.2, 1) – Decelerate
├─ Exit       : Cubic Bezier (0.4, 0.0, 1, 1) – Accelerate
```

### Micro-interactions
```
Button Press  : Scale down to 0.95 (150ms)
Card Tap      : Ripple effect + subtle scale
List Swipe    : Reveal actions (Delete, Edit)
Pull Refresh  : Spinner with ease-out
```

---

## Screen-Specific Layouts

### 1. Login / Signup
```
LAYOUT
├─ Logo (center, top 1/3 of screen)
├─ Input fields (email, password)
├─ Primary button (full width)
├─ Secondary text link (center, below button)

SPACING
├─ Screen padding: 24px
├─ Field gap: 16px
```

### 2. Homepage (Task List)
```
LAYOUT
├─ App bar (Title: "My Tasks", Filter icon)
├─ Tab bar (Ongoing | Past)
├─ Task list (scrollable)
├─ FAB (bottom-right, create task)

EMPTY STATE
├─ Illustration (center)
├─ Text: "No tasks yet"
├─ Secondary action: "Create your first task"
```

### 3. Task Detail
```
LAYOUT
├─ App bar (Back, Task ID)
├─ Scrollable content:
│   ├─ Title (H2)
│   ├─ Subtitle/Description (Body)
│   ├─ Metadata (Assignee, Deadline, Status)
│   ├─ Divider
│   ├─ Remarks section (list)
├─ Sticky bottom action bar:
│   ├─ Add Remark | Mark Complete | Reschedule

SPACING
├─ Content padding: 16px
├─ Section gap: 24px
```

### 4. Admin Dashboard
```
LAYOUT
├─ App bar (Title: "Dashboard")
├─ Metrics cards (grid, 2 columns):
│   ├─ Active Tasks
│   ├─ Overdue Tasks
│   ├─ Teams
│   ├─ Pending Approvals
├─ Quick actions:
│   ├─ Approve Requests
│   ├─ Manage Teams
│   ├─ Export Report

SPACING
├─ Card gap: 12px
├─ Section padding: 16px
```

---

## Accessibility Standards

### Contrast Ratios (WCAG AA)
```
Normal Text (16px)  : Minimum 4.5:1
Large Text (18px+)  : Minimum 3:1
UI Components       : Minimum 3:1
```

### Touch Targets
```
Minimum Size : 48x48px (44x44px iOS)
Spacing      : 8px between adjacent targets
```

### Screen Reader Support
```
All buttons       : contentDescription / semanticLabel
Images            : alt text
Status changes    : Live region announcements
```

---

## Dark Mode Implementation

### Toggle Behavior
- **User Control**: Settings screen toggle (persisted to local storage)
- **Default**: System preference (MediaQuery.platformBrightness)

### Transition
- **Animation**: Smooth color fade (350ms) when toggling
- **Scope**: Entire app updates simultaneously (no flickering)

---

## Design Assets Checklist

### Required Assets
- [ ] App logo (SVG + PNG @1x, @2x, @3x)
- [ ] App icon (iOS & Android, all required sizes)
- [ ] Splash screen (Light & Dark variants)
- [ ] Empty state illustrations (No tasks, No teams, No notifications)
- [ ] Default user avatar (SVG)

### Icon Set
- [ ] Material Icons package installed
- [ ] Custom icons (if any) exported as SVG

---

## Figma / Design Handoff (Optional)

If design mockups are provided:
1. Use **Figma Dev Mode** for accurate spacing/color extraction
2. Export assets at **@2x, @3x** for iOS, **mdpi/hdpi/xhdpi/xxhdpi** for Android
3. Verify **color hex codes** match this spec
4. Ensure **typography line-heights** are pixel-perfect

---

## Notes for Developers

### Flutter Implementation
```dart
// Define theme in a centralized ThemeData class
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: Color(0xFF2563EB),
    scaffoldBackgroundColor: Color(0xFFFFFFFF),
    // ... rest of theme
  );
  
  static ThemeData darkTheme = ThemeData(
    primaryColor: Color(0xFF3B82F6),
    scaffoldBackgroundColor: Color(0xFF0F172A),
    // ... rest of theme
  );
}
```

### Reusable Components
Create custom widgets for:
- `AppButton` (primary, secondary, icon variants)
- `AppCard` (standard, elevated)
- `TaskListItem`
- `StatusBadge`
- `AppTextField`

---

## Version History
- **v1.0** (2025-11-23): Initial design system for MVP
