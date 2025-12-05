# Defining Design System (design.md) - Foundational Rule

**Purpose**: Create a comprehensive global design system specification from initial design images.

**Input**: 3-5 design images representing different screens/modules  
**Output**: Complete `design.md` file with design tokens, components, and usage guidelines

**Document Type**: Foundational - Serves any project, not screen-specific  
**Critical**: This is the single source of truth for all design implementation

---

## 1. What to Deliver

Your `design.md` file must contain these core sections:

### 1.1 Document Header
```markdown
# {ProjectName} – Global Design System (Design Spec)
Version: 1.0.0
Last updated: {YYYY-MM-DD}
Owners: Design, Frontend Engineering
Source of truth: {Figma/Sketch/Other - link}
```

### 1.2 Purpose & Scope
- Clear statement of what the design system covers
- Modules/screens included (auth, onboarding, main flows, etc.)
- Design principles and brand personality

### 1.3 Design Tokens (Single Source of Truth)

**Color Palette**
- Primary colors (50-900 scale for main brand color)
- Text colors (primary, secondary, tertiary, inverse)
- Neutral colors (50-900 scale for grays/backgrounds)
- Background colors (app, surface, overlay)
- Semantic colors (success, warning, error, info)
- Any gradients used

**Typography**
- Font family/families
- Type scale with sizes, line heights, weights
- Usage mapping (Display, H1-H6, Body, Caption, Button, etc.)

**Spacing Scale**
- Based on 4pt or 8pt grid
- Common values (4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, etc.)
- Usage notes (section gaps, component padding, etc.)

**Border Radius**
- Named values (none, sm, md, lg, xl, full)
- Pixel values for each
- Usage (buttons, cards, inputs, etc.)

**Elevation & Shadows**
- Multiple elevation levels (0-3 typically)
- Shadow specs (x, y, blur, spread, color with opacity)
- Platform considerations (Android/iOS differences)

**Motion/Animation**
- Duration values (fast, default, slow)
- Easing curves (standard, decelerate, accelerate)

**Breakpoints** (if responsive)
- Mobile, tablet, desktop thresholds
- Target device dimensions

**Iconography**
- Grid size, stroke width
- Size variants (16, 20, 24, 32, etc.)
- Style (outlined, filled, etc.)

### 1.4 Theming
- Light theme specifications
- Dark theme specifications (if applicable)
- State overlays (hover, focus, pressed, disabled)

### 1.5 Component Specifications

For each reusable component type:
- Sizes/variants (sm, md, lg)
- Dimensions (height, padding, etc.)
- States (default, hover, pressed, disabled, focus)
- Content rules (icon placement, text styles, etc.)

**Common Components to Document**:
- Buttons (primary, secondary, tertiary, destructive)
- Input fields
- Chips/Pills/Tags
- Cards/Tiles
- Modals/Bottom sheets
- Navigation (top bar, bottom nav, tabs)
- Progress indicators (bars, dots, spinners)
- Feedback components (snackbars, toasts, alerts)

### 1.6 Layout Templates
- Screen-type patterns (auth, onboarding, list, detail, etc.)
- Vertical rhythm rules
- Content width constraints
- Common composition patterns

### 1.7 Accessibility (A11y)
- Contrast requirements (AA/AAA)
- Touch target minimums
- Dynamic type support
- Focus indicators
- Semantic labeling

### 1.8 Assets & Naming Conventions
- Directory structure
- File naming patterns
- Export formats (SVG, PNG, WebP, etc.)

### 1.9 Code Integration Examples
- Sample code showing token usage
- Theme mapping examples
- Anti-patterns to avoid

### 1.10 Changelog
- Version history with dates
- Major changes documented

---

## 2. Guidelines for Creation

### Step 1: Analyze Design Images (All 3-5 at Once)

**Look for patterns across all images:**
- What colors appear repeatedly?
- What font sizes/weights are used?
- What spacing values recur?
- What component shapes/styles repeat?

**Extract systematically:**
1. Open all design images side-by-side
2. Use design tools (Figma/Sketch) or eyedropper/measure tools
3. Document exact hex values, pixel measurements, font specs
4. Note where each element appears (to determine scope: app-wide vs module-specific)

### Step 2: Build Color System

**Primary Color**:
- Identify the main brand color
- If only one shade provided, generate a scale (50-900)
- Use color tools (like https://uicolors.app) to generate harmonious scales
- Test contrast ratios

**Text Colors**:
- Extract dark text color (headings) → textPrimary
- Extract lighter text (body) → textSecondary
- Extract lightest text (captions) → textTertiary
- White/inverse text for dark backgrounds

**Neutrals**:
- Extract all gray shades used
- Create 50-900 scale for consistency
- Map to use cases (borders, backgrounds, disabled states)

**Semantic Colors**:
- If success/error/warning states shown, extract those
- If not shown, define standard values (green success, red error, etc.)

### Step 3: Build Typography System

**Identify Font Family**:
- Note exact font name(s) from designs
- Verify availability (Google Fonts, system fonts, custom)

**Extract Type Scale**:
- Measure all text sizes in designs (in px/pt)
- Note line heights (measure or calculate from visual spacing)
- Note font weights used
- Group into hierarchy (Display > H1 > H2 > Body > Caption)

**Create Mapping**:
```
Display: 32/38 (size/lineHeight), weight 700
H1: 28/34, weight 700
H2: 24/30, weight 600
Title: 20/26, weight 600
Body: 16/24, weight 400
Body-sm: 14/20, weight 400
Caption: 12/16, weight 500
Button: 16/20, weight 600, letterSpacing 0.1
```

### Step 4: Extract Spacing & Sizing

**Method**:
- Measure gaps between elements
- Measure padding inside components
- Measure margins around sections

**Create Scale**:
- If using 8pt grid: 0, 8, 16, 24, 32, 40, 48, 56, 64
- If using 4pt grid: 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 48, 56, 64

**Document Usage**:
- Section gaps: typically 24-32
- Component internal padding: typically 12-16
- Inline spacing: typically 8-12

### Step 5: Define Components

**For each component type:**

1. **Identify all variants** across the designs
   - Primary button, secondary button, text button?
   - Different input types?
   - Multiple card styles?

2. **Measure specifications**:
   - Height (e.g., button: 48px)
   - Border radius (e.g., 12px)
   - Padding (horizontal, vertical)
   - Shadow (if any)

3. **Document states** (if shown or implied):
   - Default appearance
   - Hover (often slightly darker)
   - Pressed (darker still)
   - Disabled (lower opacity or gray)
   - Focus (often outline or glow)

4. **Note content rules**:
   - Icon size and placement
   - Text style to use
   - Icon-text gap

### Step 6: Verify Consistency

**Cross-check all extracted values:**
- Are button heights consistent across screens?
- Are corner radii the same for similar components?
- Do text sizes follow a logical scale?
- Are colors used consistently (same hex for same purpose)?

**If inconsistencies found:**
- Note them as design review items
- Choose the most common value as standard
- Document exceptions if intentional

### Step 7: Code Examples

**Create sample code blocks** showing:
- How to use color tokens: `AppColors.primary500`
- How to apply typography: `AppTypography.h1`
- How to use spacing: `AppSpacing.md`
- **Anti-patterns**: Show hardcoded values as ❌ wrong

---

## 3. What to Prevent

### ❌ Mistake 1: Hardcoded Values in Design Doc
**Wrong**: "Use #FF7A45 for buttons"  
**Right**: "Primary color: `#FF7A45` (use via `AppColors.primary500`)"

### ❌ Mistake 2: Incomplete Scales
**Wrong**: Documenting only the exact shades in designs  
**Right**: Creating full 50-900 scales for colors, complete type scale

### ❌ Mistake 3: Missing State Specifications
**Wrong**: Only documenting default button appearance  
**Right**: Documenting default, hover, pressed, disabled, focus states

### ❌ Mistake 4: Vague Measurements
**Wrong**: "Large padding" or "Small text"  
**Right**: "Padding: 16px" or "Caption: 12px/16px line height"

### ❌ Mistake 5: Screen-Specific Specs
**Wrong**: "Login button is 56px high"  
**Right**: "Primary button (app-wide): 56px high, used on login and signup"

### ❌ Mistake 6: No Usage Guidance
**Wrong**: Just listing token values without context  
**Right**: Including usage notes, examples, and anti-patterns

### ❌ Mistake 7: Platform Conflicts
**Wrong**: Ignoring Android/iOS differences  
**Right**: Noting platform-specific adjustments (elevation, shadows, ripples)

### ❌ Mistake 8: Inaccessible Combinations
**Wrong**: Using color combinations with poor contrast  
**Right**: Verifying AA/AAA contrast ratios, documenting minimums

### ❌ Mistake 9: No Versioning
**Wrong**: Updating the doc without tracking changes  
**Right**: Maintaining changelog, updating version number

### ❌ Mistake 10: Forgetting Code Integration
**Wrong**: Only design specs without implementation guidance  
**Right**: Including code examples in target framework (Flutter, React, etc.)

---

## 4. Quality Checklist

Before finalizing `design.md`:

**Completeness**:
- [ ] All sections present (1.1 through 1.10)
- [ ] Color palette includes primary, text, neutral, background, semantic
- [ ] Typography scale is complete (Display → Caption)
- [ ] Spacing scale follows consistent grid (4pt or 8pt)
- [ ] Border radius values documented
- [ ] Elevation/shadows specified with exact values
- [ ] All major component types documented
- [ ] States documented for interactive components
- [ ] Code examples included

**Accuracy**:
- [ ] All hex values extracted exactly from designs
- [ ] All measurements in consistent units (px or pt)
- [ ] Font names verified for availability
- [ ] Contrast ratios checked (minimum AA)
- [ ] Values cross-verified across all design images

**Consistency**:
- [ ] Same component type has same specs across all images
- [ ] Color usage is semantically consistent
- [ ] Typography follows logical hierarchy
- [ ] Spacing follows the defined scale
- [ ] Intentional variations are documented with reasons

**Usability**:
- [ ] Clear section headings
- [ ] Usage notes for each token category
- [ ] Code examples show correct and incorrect usage
- [ ] Anti-patterns clearly marked
- [ ] Platform-specific notes where applicable

**Maintenance**:
- [ ] Version number and date at top
- [ ] Source of truth (Figma link) documented
- [ ] Changelog section started
- [ ] Owners/stakeholders listed

---

## 5. Examples

### Example 1: Extracting Button Spec

**From Design Images**:
- Login screen shows orange button: "Continue with Google"
- Signup screen shows same orange button: "Get Started"
- Settings screen shows white button with border: "Edit Profile"

**Extraction Process**:
1. Measure orange button: Height 56px, corner radius 12px
2. Color: #F48456
3. Measure white button: Height 56px, corner radius 12px
4. Border: 1px, color #E2E8F0

**Design.md Entry**:
```markdown
### 5.1 Buttons
- Sizes: sm=40, md=48, lg=56 (height)
- Radius: 12 (md)
- Label: Button / Inter 600 16/20
- Icon gap: 8

Variants:
- Primary (filled):
  - Default bg: primary.500 (#F48456), text: text.inverse
  - Pressed: primary.600, Disabled: neutral.200 (text neutral.500)
- Secondary (outline):
  - Border: neutral.300 (#E2E8F0), text: text.primary
  - Pressed-fill: neutral.100
```

### Example 2: Extracting Color Palette

**From Design Images**:
- Backgrounds: Warm beige (#FFF7F0), white cards
- Primary actions: Orange (#F48456, #F26B36 on press)
- Text: Dark navy (#0F172A), medium gray (#475569), light gray (#64748B)
- Borders/dividers: Light gray (#E2E8F0)

**Design.md Entry**:
```markdown
### 3.1 Color Palette (Light Theme)

```jsonc
{
  "color": {
    "primary": {
      "500": "#FF7A45",   // Default button fill
      "600": "#F26B36",   // Hover/pressed
      // ... 50-900 scale generated
    },
    "text": {
      "primary":   "#0F172A", // Headings
      "secondary": "#475569", // Body secondary
      "tertiary":  "#64748B", // Captions
      "inverse":   "#FFFFFF"
    },
    "neutral": {
      "200": "#E2E8F0", // Borders
      // ... 50-900 scale
    },
    "background": {
      "app":     "#FFF7F0", // Warm canvas
      "surface": "#FFFFFF"
    }
  }
}
```
```

---

## 6. Edge Cases & Special Situations

### Case 1: Only 1-2 Design Images Provided
**Solution**: 
- Extract what's visible
- Make educated decisions for missing scales (use industry standards)
- Note assumptions in document
- Flag for design review

### Case 2: Inconsistent Designs
**Solution**:
- Document the inconsistency
- Choose most common value as standard
- Note exceptions
- Create design review checklist

### Case 3: Complex Gradients/Effects
**Solution**:
- Use design tool to export exact gradient specs
- Document start/end colors, direction, stops
- Provide fallback solid color
- Note browser/platform support

### Case 4: Missing States (Hover, Pressed, etc.)
**Solution**:
- Infer from material design / platform guidelines
- Use color math (e.g., -10% lightness for hover)
- Document as "inferred, pending design confirmation"

### Case 5: Custom Fonts Not Available
**Solution**:
- Document custom font with acquisition instructions
- Provide fallback font stack
- Note licensing requirements

### Case 6: Conflicting Measurements
**Solution**:
- Measure multiple instances
- Choose most common value
- Round to nearest value on spacing scale
- Document original variance for designer review

---

## 7. Integration with Development

### Recommended Implementation Structure

After creating `design.md`, the development team should generate:

```
lib/core/constants/theme/
├── colors.dart          // Color tokens as constants
├── typography.dart      // TextStyle definitions
├── spacing.dart         // Spacing scale constants
├── radius.dart          // BorderRadius constants
├── shadows.dart         // BoxShadow definitions
├── light_theme.dart     // ThemeData for light mode
├── dark_theme.dart      // ThemeData for dark mode
└── export.dart          // Barrel file
```

**Your `design.md` serves as the specification document that these code files implement.**

---

## 8. Maintenance & Evolution

### When to Update `design.md`

**Must update**:
- New design images introduce new components
- Brand color changes
- Typography system changes
- New module requires new component variants

**Update process**:
1. Increment version number
2. Update relevant sections
3. Add entry to changelog
4. Notify development team
5. Update generated code files

### Version Numbering

- **Major (1.0.0 → 2.0.0)**: Breaking changes (color values change, components restructured)
- **Minor (1.0.0 → 1.1.0)**: New components added, new tokens
- **Patch (1.0.0 → 1.0.1)**: Corrections, clarifications, documentation fixes

---

## 9. Success Criteria

Your `design.md` is successful when:

- ✅ Developers can implement any screen without asking "what color is this?"
- ✅ All design tokens have clear names and values
- ✅ Component specs are detailed enough for pixel-perfect implementation
- ✅ Code examples prevent common mistakes
- ✅ Future designs can reference existing components
- ✅ Design reviews can compare new screens against documented standards
- ✅ No hardcoded values appear in implementation code
- ✅ Onboarding new developers is faster (single reference document)

---

## 10. Final Notes

**This document is foundational** - it's referenced by:
- Module-specific design files (`assets/designs/{module}/design.md`)
- Implementation guidelines (Step 4)
- DesignMap validation (Step 2.5)
- All screen implementations

**Time investment**: 
- Initial creation: 4-8 hours for thorough extraction
- Maintenance: 1-2 hours per major design update

**ROI**:
- Saves 10-20% development time (no guessing, no rework)
- Prevents design drift
- Enables design system evolution
- Documents design decisions

---

**Document Status**: Foundational Guideline  
**Applies To**: Any project with visual designs  
**Creates**: `.windsurf/design.md`  
**Next Step**: Use this design.md as parent spec for all module design files
