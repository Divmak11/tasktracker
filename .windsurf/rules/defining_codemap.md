# Defining CodeMap (CodeMap.md) - Foundational Rule

**Purpose**: Create a comprehensive technical reference document for any codebase.

**Input**: Existing codebase (any size, any framework)  
**Output**: Complete `CodeMap.md` serving as the project's technical documentation

**Document Type**: Foundational - Serves any project/framework  
**Critical**: This is the single source of truth for project architecture and patterns

---

## 1. What to Deliver

Your `CodeMap.md` file must contain these core sections:

### 1.1 Document Header
```markdown
# {ProjectName} - CodeMap & Technical Reference
**Version:** {X.Y.Z}  
**Last Updated:** {YYYY-MM-DD}  
**Project Version:** {from package.json/pubspec.yaml/etc.}
```

### 1.2 Table of Contents
List all major sections with anchor links for navigation.

### 1.3 Project Overview

**Tech Stack**:
- Framework and version
- State management solution
- Backend services (Firebase, REST API, GraphQL, etc.)
- Local storage solution
- Push notifications
- Authentication method
- Network libraries
- UI libraries and tools

**Architecture Pattern**:
- High-level directory structure
- Core architectural pattern (MVC, MVVM, Clean, etc.)

**Core Modules**:
- List major functional modules (Auth, Data Sync, Payments, etc.)

### 1.4 Directory Structure

**Complete file organization** showing:
- Purpose of each directory
- Key files and their responsibilities
- Patterns and conventions

```
lib/
├── main.dart                    // App entry point & initialization
├── config.dart                  // Configuration
└── core/
    ├── constants/              // App constants
    ├── models/                 // Data models
    ├── services/               // Service layer (API, storage, etc.)
    ├── controllers/            // State management
    └── screens/                // UI screens
```

### 1.5 Database/Data Layer Schemas

**For each data store**:
- Database collections/tables
- Field types and descriptions
- Relationships
- Indexes (if relevant)
- Local storage keys and structures

Examples:
- Firestore collections
- SQL tables
- Local storage (SharedPreferences, Hive, etc.)
- API response structures

### 1.6 Identifier Semantics

**Key identifiers explained**:
- User IDs (format, source, usage)
- Resource IDs
- Transaction IDs
- External service IDs (OneSignal, Firebase, etc.)

**Observable/Reactive patterns** (if used):
- Variable naming conventions
- Access patterns

### 1.7 Query/API Patterns

**Common query patterns** with code examples:
- Authentication flows
- Data fetching
- Data mutation (create, update, delete)
- Error handling patterns
- Retry logic

### 1.8 Data Handling Conventions

**Standards for**:
- Date/time formats (ISO 8601, timestamps, etc.)
- Null safety patterns
- JSON encoding/decoding
- Data validation
- Error responses

### 1.9 State Management

**State management approach**:
- Navigation patterns
- Reactive state management
- Global state variables
- State persistence

### 1.10 Component Architecture

**Initialization sequence**:
- App startup steps (in order)
- Service initialization
- Configuration setup

**UI Component patterns**:
- Widget/component structure
- Theming configuration
- Common UI patterns

**Service layer patterns**:
- How services are structured
- Singleton vs instance patterns
- Dependency injection approach

### 1.11 Core Functions & Data Flow

**Critical flows documented**:
- Authentication flow (step-by-step)
- Data sync flow
- Payment flow (if applicable)
- Push notification handling

Include flowcharts or step-by-step walkthroughs.

### 1.12 Design Documentation Workflow

**If design system exists**:
- Hierarchy (global → module → implementation)
- How design files relate to code
- Design decode workflow (if applicable)
- Token usage patterns

### 1.13 Known Pitfalls & Solutions

**Common issues and fixes**:
- Version compatibility issues
- Platform-specific problems
- Anti-patterns to avoid
- Typos or tech debt to address

### 1.14 Debugging Helpers

**Development tools**:
- Logging patterns
- Common debug points
- Performance monitoring
- Helpful console commands

### 1.15 Quick Reference

**Essential file locations table**:
| Purpose | File Path |
|---------|-----------|
| App Entry | `/path/to/main` |
| Auth Logic | `/path/to/auth` |
| Config | `/path/to/config` |

**Key functions reference**:
Code snippets for common operations.

**Environment variables & constants**:
All configuration values documented.

**Common patterns**:
Frequently used code patterns with examples.

### 1.16 Maintenance Guidelines

**When and how to update**:
- Adding new features
- Version control procedures
- Breaking change documentation
- Code quality checks

### 1.17 Critical Information for AI/Developers

**Top-level rules**:
- Non-negotiable patterns
- Required imports
- Framework-specific gotchas
- Consistency requirements

---

## 2. Guidelines for Creation

### Step 1: Understand the Codebase Structure

**Initial exploration**:
1. Identify the project root
2. Find main entry point (main.dart, index.js, app.py, etc.)
3. Locate configuration files (package.json, pubspec.yaml, etc.)
4. Map out directory structure
5. Identify framework and version

**Tools to use**:
- File tree command: `tree -L 3 -I 'node_modules|.git'`
- Dependency lists: package.json, requirements.txt, pubspec.yaml
- IDE project structure view
- Git history (to understand evolution)

### Step 2: Document Tech Stack

**Extract from**:
- Package/dependency files
- Import statements at the top of files
- Configuration files
- README (if exists)

**Note versions**:
- Framework version
- Major library versions
- Minimum platform requirements

### Step 3: Map Directory Structure

**For each directory**:
- What type of code belongs here?
- What's the naming convention?
- Are there subdirectories? What do they contain?

**Document patterns**:
- `models/` → Data classes
- `services/` → External interactions (API, storage, etc.)
- `controllers/` → Business logic
- `screens/` → UI components

### Step 4: Extract Data Schemas

**For databases**:
- List all collections/tables
- Document field types
- Note required vs optional fields
- Document relationships

**For local storage**:
- List all keys
- Document value types
- Note usage (what each key stores)

**For APIs**:
- Document endpoint patterns
- Request/response structures
- Authentication requirements

### Step 5: Identify Core Patterns

**Look for**:
- How is navigation handled?
- How is state managed?
- How are errors handled?
- How is data fetched/mutated?

**Document with code examples**:
```dart
// Navigation pattern
Get.to(() => ScreenName());

// State management pattern
RxString username = ''.obs;
```

### Step 6: Trace Critical Flows

**Pick 2-3 critical user flows**:
1. User authentication
2. Main feature usage
3. Data synchronization (if applicable)

**Document step-by-step**:
```
User taps login → AuthController.login()
  ├→ AuthService.signIn()
  ├→ Store user data
  ├→ Update global state
  └→ Navigate to home
```

### Step 7: Document Known Issues

**Review**:
- Git issues/PRs
- Code comments with TODOs
- Common error patterns
- Platform-specific quirks

**Document**:
- The problem
- The solution or workaround
- Why it happens
- How to prevent it

### Step 8: Create Quick Reference

**Most-used code snippets**:
- Authentication calls
- Navigation
- Data fetching
- Common widgets/components

**Essential file locations**:
- Where to find specific functionality
- Where to add new features

---

## 3. What to Prevent

### ❌ Mistake 1: Documenting What, Not How
**Wrong**: "We use Firebase"  
**Right**: "Firebase Auth pattern: `FirebaseAuth.instance.signInWithCredential()` - see AuthService.dart line 42"

### ❌ Mistake 2: Outdated Information
**Wrong**: Documenting old architecture that no longer exists  
**Right**: Verifying each section against current code, noting deprecated patterns

### ❌ Mistake 3: Missing Code Examples
**Wrong**: "Use GetX for navigation"  
**Right**: Showing actual code: `Get.to(() => HomePage())`

### ❌ Mistake 4: Vague Descriptions
**Wrong**: "Services handle API calls"  
**Right**: "AuthService handles Firebase Auth, DataService handles Firestore, ApiService handles REST endpoints"

### ❌ Mistake 5: No Version Information
**Wrong**: "Using Flutter"  
**Right**: "Flutter 3.5.1+, Dart 3.2.0"

### ❌ Mistake 6: Incomplete Flows
**Wrong**: Showing only part of authentication  
**Right**: Complete flow from UI tap to successful login to navigation

### ❌ Mistake 7: Missing File Paths
**Wrong**: "Check the auth controller"  
**Right**: "`/lib/core/controller/auth_controller.dart`"

### ❌ Mistake 8: No Quick Reference
**Wrong**: Verbose explanations without summary  
**Right**: Table of essential files + common code snippets at end

### ❌ Mistake 9: Ignoring Pitfalls
**Wrong**: Only documenting happy path  
**Right**: Including "Known Pitfalls" section with gotchas and solutions

### ❌ Mistake 10: Not Maintenance-Friendly
**Wrong**: No version number, no update date  
**Right**: Version at top, changelog section, clear ownership

---

## 4. Quality Checklist

Before finalizing `CodeMap.md`:

**Completeness**:
- [ ] All sections present (1.1 through 1.17)
- [ ] Tech stack with versions
- [ ] Complete directory structure documented
- [ ] All data schemas documented
- [ ] Core patterns shown with code examples
- [ ] At least 2-3 critical flows documented
- [ ] Known pitfalls section populated
- [ ] Quick reference section complete

**Accuracy**:
- [ ] File paths verified (actually exist)
- [ ] Code examples tested (actually work)
- [ ] Versions match actual dependencies
- [ ] Patterns match current code (not outdated)
- [ ] Data schemas match actual database/storage

**Clarity**:
- [ ] Table of contents with working links
- [ ] Section headings are descriptive
- [ ] Code examples are syntax-highlighted
- [ ] File paths use consistent format
- [ ] Explanations are concise but complete

**Usability**:
- [ ] New developer could navigate codebase using this
- [ ] Common tasks have quick reference examples
- [ ] Critical files are easy to locate
- [ ] Design workflow is clear (if applicable)
- [ ] Known issues have documented solutions

**Maintenance**:
- [ ] Version number and date at top
- [ ] Maintenance guidelines section exists
- [ ] Critical info for AI/developers section present
- [ ] Update process is clear

---

## 5. Examples

### Example 1: Documenting Authentication Flow

**Research**:
- Find auth-related files: `auth_controller.dart`, `auth_service.dart`
- Trace code from login button to completion
- Note all steps, services called, state changes

**CodeMap.md Entry**:
```markdown
### Authentication Flow
```
User Tap Login → AuthController.loginWithGoogle()
    ├→ AuthService.signInWithGoogle()
    ├→ FirestoreService.addUserData()
    ├→ Update VarConstants (username, firstLetter)
    ├→ AnalyticsService.setUserData()
    ├→ FetchService.fetchInitialData()
    └→ Navigate to Home Screen
```

**Code Example**:
```dart
Future<void> loginWithGoogle() async {
  isLoading.value = true;
  try {
    final firebaseUser = await _authService.signInWithGoogle();
    if (firebaseUser != null) {
      await _firestoreService.addUserData(/*...*/);
      VarConstants.username.value = firebaseUser.displayName ?? '';
      VarConstants.analyticsService.setUserData(userId: firebaseUser.uid);
      await FetchService.fetchInitialData();
      Get.offAllNamed('/home');
    }
  } finally {
    isLoading.value = false;
  }
}
```
```

### Example 2: Documenting Data Schema

**Research**:
- Check Firestore collections
- Review model files
- Note field types from code or database

**CodeMap.md Entry**:
```markdown
### Firestore Collections

#### Users Collection
**Path:** `/Users/{userId}`

```dart
{
  'id': String,                    // User's Firebase UID
  'name': String,                   // Display name from OAuth provider
  'email': String,                  // User email
  'registeredDate': Timestamp,     // Server timestamp of registration
  'settings': {
    'notifications': Boolean,      // Push notification preference
    'theme': String               // 'light' | 'dark' | 'system'
  }
}
```
```

### Example 3: Documenting Quick Reference

**Research**:
- Identify most-used operations
- Extract code snippets
- List essential file locations

**CodeMap.md Entry**:
```markdown
### Quick Reference

#### Essential File Locations
| Purpose | File Path |
|---------|-----------|
| App Entry | `/lib/main.dart` |
| Auth Logic | `/lib/core/controller/auth_controller.dart` |
| API Service | `/lib/core/services/api_service.dart` |

#### Common Patterns
```dart
// Authentication
AuthController.loginWithGoogle()
AuthController.logout()

// Navigation
Get.to(() => ScreenName());
Get.back();

// State
Obx(() => Text(controller.value))
```
```

---

## 6. Edge Cases & Special Situations

### Case 1: Legacy Codebase with No Clear Structure
**Solution**:
- Document current state honestly
- Note areas needing refactor
- Provide guidance for new code
- Create "Current State" vs "Desired State" sections

### Case 2: Multiple Architectures (Migration in Progress)
**Solution**:
- Document both old and new patterns
- Note which is preferred for new code
- Provide migration guide
- Mark deprecated patterns clearly

### Case 3: External Dependencies Not Well Documented
**Solution**:
- Research the library documentation
- Document how it's used in this project
- Note version-specific quirks
- Link to external docs

### Case 4: Complex Monorepo or Multi-Module Project
**Solution**:
- Create high-level CodeMap for overall structure
- Consider separate CodeMaps per module
- Cross-reference between documents
- Use clear hierarchical organization

### Case 5: Proprietary/Confidential Code Patterns
**Solution**:
- Use pseudocode or generic examples
- Document pattern without exposing secrets
- Note "See internal wiki" where applicable
- Ensure no API keys or credentials in examples

### Case 6: Rapidly Changing Codebase
**Solution**:
- Version the CodeMap heavily
- Note unstable areas
- Use "as of [date]" notations
- Set up regular update schedule (weekly/monthly)

---

## 7. Integration with Development Workflow

### How Developers Use CodeMap

**Onboarding**:
- New developer reads CodeMap first
- Understands architecture before diving into code
- Knows where to find what they need

**Feature Development**:
- Check CodeMap for existing patterns
- Follow documented conventions
- Update CodeMap when adding new patterns

**Code Review**:
- Reference CodeMap for consistency checks
- Ensure new code follows documented patterns
- Update CodeMap if intentional deviation

**Debugging**:
- Use CodeMap to understand data flow
- Check "Known Pitfalls" for common issues
- Follow documented debugging patterns

### AI-Assisted Development

**For AI tools (GitHub Copilot, Cascade, etc.)**:
- CodeMap provides context for better suggestions
- "Critical Information for AI Development" section guides AI behavior
- Patterns in CodeMap become templates for AI

---

## 8. Maintenance & Evolution

### When to Update CodeMap

**Must update**:
- New major feature added (new module, new service)
- Architecture changes (migration to new state management, etc.)
- New critical pattern established
- Major dependency upgrade with breaking changes
- Known pitfall discovered and solved

**Update process**:
1. Increment version number
2. Update date
3. Modify relevant sections
4. Add changelog entry
5. Notify team

### Version Numbering

- **Major (1.0.0 → 2.0.0)**: Architecture overhaul, framework migration
- **Minor (1.0.0 → 1.1.0)**: New modules, new patterns, significant additions
- **Patch (1.0.0 → 1.0.1)**: Corrections, clarifications, small additions

### Review Schedule

**Recommended**:
- Quick review: After each sprint/iteration
- Deep review: Quarterly
- Full audit: Annually or on major releases

---

## 9. Success Criteria

Your `CodeMap.md` is successful when:

- ✅ New developers can onboard 50% faster
- ✅ Common questions have documented answers
- ✅ Code review consistency improves
- ✅ AI tools generate more accurate code
- ✅ Design-to-implementation handoff is smoother
- ✅ Technical debt is documented and tracked
- ✅ No "tribal knowledge" - everything is written down
- ✅ Emergency debugging is faster (flows documented)

---

## 10. Platform-Specific Considerations

### For Mobile Apps (Flutter, React Native, iOS, Android)

**Additional sections to include**:
- Platform-specific code (iOS vs Android)
- Permission handling patterns
- Deep linking structure
- Push notification setup
- App lifecycle management
- Platform channel usage (if any)

### For Web Apps (React, Vue, Angular)

**Additional sections to include**:
- Routing configuration
- State hydration/SSR (if applicable)
- Build configuration
- Environment variables
- API base URLs and endpoints
- Browser compatibility notes

### For Backend/API Services

**Additional sections to include**:
- API endpoint documentation
- Middleware pipeline
- Authentication/authorization flow
- Database connection pooling
- Caching strategies
- Rate limiting
- Error response formats
- Deployment process

### For Full-Stack Applications

**Additional sections to include**:
- Client-server communication patterns
- API versioning strategy
- Data synchronization approach
- Offline-first considerations (if applicable)
- WebSocket/real-time connection handling

---

## 11. Template Starters

### Minimal CodeMap (Small Project)

```markdown
# {Project} - CodeMap

**Version:** 1.0.0  
**Last Updated:** {date}

## Tech Stack
- {Framework} {version}
- {Major dependencies}

## Directory Structure
```
{tree structure}
```

## Core Patterns

### Navigation
```{language}
{code example}
```

### State Management
```{language}
{code example}
```

## Quick Reference
| Purpose | File |
|---------|------|
| {Key files table} |
```

### Comprehensive CodeMap (Large Project)

Use all sections from **Section 1.1 - 1.17** above.

---

## 12. Collaboration Guidelines

### Multi-Author CodeMap

**If multiple people maintain CodeMap**:
- Assign ownership per section (Auth team owns auth flow, etc.)
- Use version control (Git) for CodeMap itself
- Review changes like code (PR process)
- Resolve conflicts by referring to actual code
- Keep style consistent (templates help)

### Living Document Philosophy

**CodeMap is never "done"**:
- Evolves with codebase
- Gets more valuable over time
- Starts imperfect, improves iteratively
- Better to have 80% complete than 0%

---

## 13. Final Notes

**Time Investment**:
- Initial creation (small project): 4-8 hours
- Initial creation (large project): 16-40 hours
- Maintenance: 1-2 hours per sprint/month

**ROI**:
- Onboarding time: -50%
- Code review time: -20%
- Debugging time: -15%
- Design implementation time: -10%
- Knowledge loss risk: -80%

**Relationship to Other Docs**:
- **design.md**: CodeMap references it for UI patterns
- **README.md**: CodeMap expands on README's overview
- **API docs**: CodeMap links to them
- **Rule files**: CodeMap documents their location and purpose

---

**Document Status**: Foundational Guideline  
**Applies To**: Any codebase (any language, any framework)  
**Creates**: `.windsurf/CodeMap.md`  
**Complements**: Design system documentation, API documentation, README
