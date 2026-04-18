# Vortex

A lightweight macOS menu bar app for managing hierarchical to-do lists. Lives in your status bar — out of the way until you need it.

---

## What it does

Vortex organises your tasks in a three-level hierarchy:

```
Tab  →  Category  →  Sub-Category  →  Task
```

- **Tabs** — top-level groupings (e.g. Work, Personal, Travel)
- **Categories** — groups within a tab (e.g. Project Alpha, Admin)
- **Sub-Categories** — optional deeper grouping within a category
- **Tasks** — individual to-do items; can live directly on a category without needing a sub-category

### Features

| Feature | Details |
|---------|---------|
| **Status bar icon** | Always accessible; shows a count of pending tasks |
| **Hierarchical todos** | Tab → Category → Sub-Category → Task |
| **Optional priority** | High / Medium / Low, shown as a colour dot next to the task |
| **Optional due date** | Shown inline; overdue dates highlighted in red |
| **Hide completed** | Done tasks are hidden by default; toggle the eye icon to reveal them |
| **Search** | Filters tasks across all levels in real time; hides empty parents automatically |
| **Collapse / expand** | Each level can be collapsed; state is persisted between sessions |
| **Launch at login** | Right-click the status bar icon → toggle "Launch at Login" |
| **Local storage** | All data stored on-device via CoreData — no account, no cloud |

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (for building from source)

---

## Install

### Option A — Download the DMG (easiest)

A pre-built DMG is available in the [`artifacts/`](artifacts/) folder in this repository.

1. Download **`artifacts/Vortex.dmg`**
2. Open it, drag **Vortex.app** into **Applications**
3. Launch Vortex from Applications or Spotlight

> **Note:** Because the app is not notarised, macOS may show a security warning on first launch. To open it anyway: right-click **Vortex.app** → **Open** → **Open**.

### Option B — Build the DMG yourself

```bash
git clone git@github.com:ArchanaAsokan/vortex.git
cd vortex
bash scripts/build-dmg.sh
```

This produces `dist/Vortex.dmg`. Open it, drag **Vortex.app** into **Applications**, then launch it from there.

```bash
open dist/Vortex.dmg
```

### Option C — Run directly from Xcode

```bash
git clone git@github.com:ArchanaAsokan/vortex.git
cd vortex
open Vortex.xcodeproj
```

Select the **Vortex** scheme, press **⌘R** to build and run.

---

## Build script details

`scripts/build-dmg.sh` does the following:

1. Compiles the app in **Release** configuration using `xcodebuild`
2. Stages the `.app` bundle alongside a symlink to `/Applications` (enabling drag-to-install in Finder)
3. Packages everything into a compressed DMG using `hdiutil` (built into macOS — no extra tools needed)
4. Outputs the DMG to `dist/Vortex.dmg`

The script cleans up all intermediate build artefacts automatically.

**Options** (edit at the top of the script):

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `Vortex` | App and DMG name |
| `CONFIGURATION` | `Release` | Xcode build configuration |
| `OUTPUT_DIR` | `./dist` | Where the DMG is written |

---

## Project structure

```
vortex/
├── Sources/Vortex/
│   ├── VortexApp.swift           # App entry point
│   ├── AppDelegate.swift         # Status bar item, popover, settings menu
│   ├── Models/                   # CoreData entities + NSManagedObject subclasses
│   ├── Persistence/              # CoreData stack
│   ├── ViewModels/               # TodoViewModel (fetch, filter, state)
│   ├── Helpers/                  # EventMonitor, LoginItemManager
│   └── Views/
│       ├── StatusBarView.swift   # Root view: search bar + tab bar + category list
│       └── Components/           # CategoryRow, SubCategoryRow, TodoItemRow, Sheets
├── artifacts/
│   └── Vortex.dmg               # Pre-built DMG for direct download
├── scripts/
│   └── build-dmg.sh             # Build + package script
├── project.yml                   # XcodeGen project spec
└── Vortex.xcodeproj/
```
