# Task Drag-to-Reorder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to drag-and-drop `TodoItem` rows to reorder them within a container (category/subcategory) and move them across containers.

**Architecture:** Mirror the existing `TabDropDelegate`/`CategoryDropDelegate` pattern in `StatusBarView.swift`. Add `draggingItem` state + `moveItem`/`appendItem` helpers to `TodoViewModel`. Wire `.onDrag`/`.onDrop` in `CategoryRow` and `SubCategoryRow` where items are rendered.

**Tech Stack:** Swift, SwiftUI (`onDrag`/`onDrop`/`DropDelegate`), Core Data

---

### Task 1: Add `moveItem` and `appendItem` to `TodoViewModel`

**Files:**
- Modify: `Sources/Vortex/ViewModels/TodoViewModel.swift`

**Step 1: Add `draggingItem` published property and two move helpers**

Open `Sources/Vortex/ViewModels/TodoViewModel.swift`. After the existing `// MARK: - Reorder helpers` section (around line 147), add:

```swift
@Published var draggingItem: TodoItem?

func moveItem(_ item: TodoItem, before target: TodoItem,
              toCategory: Category?, toSubcategory: SubCategory?) {
    // Collect items in the destination container (excluding the dragged item)
    let destItems = itemsInContainer(category: toCategory, subcategory: toSubcategory)
        .filter { $0 != item }

    // Find insertion index
    guard let targetIdx = destItems.firstIndex(of: target) else { return }

    // Re-assign container relationships
    item.category = toCategory
    item.subcategory = toSubcategory

    // Build new ordered list and assign order values
    var newOrder = destItems
    newOrder.insert(item, at: targetIdx)
    for (i, t) in newOrder.enumerated() { t.order = Int16(i) }

    // Compact source container if it changed
    compactOrder(category: item.category, subcategory: item.subcategory)

    PersistenceController.shared.save()
}

func appendItem(_ item: TodoItem,
                toCategory: Category?, toSubcategory: SubCategory?) {
    let existing = itemsInContainer(category: toCategory, subcategory: toSubcategory)
        .filter { $0 != item }
    item.category = toCategory
    item.subcategory = toSubcategory
    item.order = Int16((existing.map { Int($0.order) }.max() ?? -1) + 1)
    PersistenceController.shared.save()
}

// Returns all items in a container regardless of showCompleted/search filters
private func itemsInContainer(category: Category?, subcategory: SubCategory?) -> [TodoItem] {
    let req = TodoItem.fetchRequest()
    if let sub = subcategory {
        req.predicate = NSPredicate(format: "subcategory == %@", sub)
    } else if let cat = category {
        req.predicate = NSPredicate(format: "category == %@ AND subcategory == nil", cat)
    } else {
        return []
    }
    req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                           NSSortDescriptor(key: "createdAt", ascending: true)]
    return (try? context.fetch(req)) ?? []
}

private func compactOrder(category: Category?, subcategory: SubCategory?) {
    let items = itemsInContainer(category: category, subcategory: subcategory)
    for (i, item) in items.enumerated() { item.order = Int16(i) }
}
```

Note: `draggingItem` must be declared alongside the other `@Published` properties near the top of the class, not inside the helpers section. Add it after `@Published var searchText: String = ""`.

**Step 2: Build the app to verify no compile errors**

In Xcode: Product → Build (⌘B), or run:
```bash
cd /Users/archasok/archanaasokan/vortex
xcodebuild -scheme Vortex build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add Sources/Vortex/ViewModels/TodoViewModel.swift
git commit -m "feat: add moveItem/appendItem helpers to TodoViewModel"
```

---

### Task 2: Add `ItemDropDelegate` and `ItemAppendDropDelegate` to `StatusBarView.swift`

**Files:**
- Modify: `Sources/Vortex/Views/StatusBarView.swift`

**Step 1: Add the two drop delegates at the bottom of the file**

Open `Sources/Vortex/Views/StatusBarView.swift`. After the closing brace of `CategoryDropDelegate` (the last struct in the file, around line 301), add:

```swift
private struct ItemDropDelegate: DropDelegate {
    let target: TodoItem
    let targetCategory: Category?
    let targetSubcategory: SubCategory?
    @Binding var dragging: TodoItem?
    let vm: TodoViewModel

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        vm.moveItem(dragging, before: target,
                    toCategory: targetCategory, toSubcategory: targetSubcategory)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct ItemAppendDropDelegate: DropDelegate {
    let targetCategory: Category?
    let targetSubcategory: SubCategory?
    @Binding var dragging: TodoItem?
    let vm: TodoViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let dragging else { return false }
        vm.appendItem(dragging, toCategory: targetCategory, toSubcategory: targetSubcategory)
        self.dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme Vortex build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add Sources/Vortex/Views/StatusBarView.swift
git commit -m "feat: add ItemDropDelegate and ItemAppendDropDelegate"
```

---

### Task 3: Wire drag/drop onto items in `CategoryRow`

`CategoryRow` renders direct items (tasks with no subcategory) in its `ForEach(directItems)` loop.

**Files:**
- Modify: `Sources/Vortex/Views/Components/CategoryRow.swift`

**Step 1: Replace the `ForEach(directItems)` block**

Find this block (around line 91–94):

```swift
// ── Direct tasks (no sub-category) ───────
ForEach(directItems) { item in
    TodoItemRow(item: item)
        .padding(.leading, 8)
}
```

Replace with:

```swift
// ── Direct tasks (no sub-category) ───────
ForEach(directItems) { item in
    TodoItemRow(item: item)
        .padding(.leading, 8)
        .opacity(vm.draggingItem?.id == item.id ? 0.4 : 1.0)
        .onDrag {
            vm.draggingItem = item
            return NSItemProvider(object: (item.id?.uuidString ?? "") as NSString)
        }
        .onDrop(
            of: [.plainText],
            delegate: ItemDropDelegate(
                target: item,
                targetCategory: category,
                targetSubcategory: nil,
                dragging: $vm.draggingItem,
                vm: vm
            )
        )
}
```

Note: `ItemDropDelegate` is `private` inside `StatusBarView.swift`. Since `CategoryRow` is in a different file, you must either make these delegates `internal` (remove `private`) or move them to their own file. **Remove the `private` modifier from both `ItemDropDelegate` and `ItemAppendDropDelegate` in `StatusBarView.swift`.**

**Step 2: Add empty-container drop zone**

Find the empty state block for direct items inside `CategoryRow` (around line 103–128, the `if directItems.isEmpty && subcategories.isEmpty` block). Replace the wrapping `HStack` with a `VStack` that includes a transparent drop zone above the existing content:

```swift
if directItems.isEmpty && subcategories.isEmpty {
    Color.clear
        .frame(maxWidth: .infinity)
        .frame(height: 8)
        .onDrop(
            of: [.plainText],
            delegate: ItemAppendDropDelegate(
                targetCategory: category,
                targetSubcategory: nil,
                dragging: $vm.draggingItem,
                vm: vm
            )
        )
    HStack(spacing: 12) {
        Button {
            showAddDirectItem = true
        } label: {
            Label("Add Task", systemImage: "plus.circle")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)

        Text("·").foregroundStyle(.tertiary)

        Button {
            showAddSubCategory = true
        } label: {
            Label("Add Sub-Category", systemImage: "folder.badge.plus")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 30)
    .padding(.vertical, 5)
}
```

**Step 3: Build**

```bash
xcodebuild -scheme Vortex build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add Sources/Vortex/Views/Components/CategoryRow.swift Sources/Vortex/Views/StatusBarView.swift
git commit -m "feat: wire item drag/drop in CategoryRow"
```

---

### Task 4: Wire drag/drop onto items in `SubCategoryRow`

**Files:**
- Modify: `Sources/Vortex/Views/Components/SubCategoryRow.swift`

**Step 1: Replace the `ForEach(visibleItems)` block**

Find (around line 99–102):

```swift
ForEach(visibleItems) { item in
    TodoItemRow(item: item)
        .padding(.leading, 16)
}
```

Replace with:

```swift
ForEach(visibleItems) { item in
    TodoItemRow(item: item)
        .padding(.leading, 16)
        .opacity(vm.draggingItem?.id == item.id ? 0.4 : 1.0)
        .onDrag {
            vm.draggingItem = item
            return NSItemProvider(object: (item.id?.uuidString ?? "") as NSString)
        }
        .onDrop(
            of: [.plainText],
            delegate: ItemDropDelegate(
                target: item,
                targetCategory: subcategory.category,
                targetSubcategory: subcategory,
                dragging: $vm.draggingItem,
                vm: vm
            )
        )
}
```

**Step 2: Add empty-container drop zone**

Find the empty state button (around line 86–97):

```swift
Button {
    showAddItem = true
} label: {
    Text("Add a task…")
        .font(.caption)
        .foregroundStyle(Color.secondary.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 36)
        .padding(.vertical, 4)
}
.buttonStyle(.plain)
```

Replace with:

```swift
ZStack {
    Color.clear
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .onDrop(
            of: [.plainText],
            delegate: ItemAppendDropDelegate(
                targetCategory: subcategory.category,
                targetSubcategory: subcategory,
                dragging: $vm.draggingItem,
                vm: vm
            )
        )
    Button {
        showAddItem = true
    } label: {
        Text("Add a task…")
            .font(.caption)
            .foregroundStyle(Color.secondary.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 36)
            .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
}
```

**Step 3: Build**

```bash
xcodebuild -scheme Vortex build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add Sources/Vortex/Views/Components/SubCategoryRow.swift
git commit -m "feat: wire item drag/drop in SubCategoryRow"
```

---

### Task 5: Manual smoke test

Run the app and verify:

1. **Reorder within a category** — drag a direct task up/down within the same category; order persists after closing and reopening the popover.
2. **Reorder within a subcategory** — drag a task within a subcategory; order persists.
3. **Move across subcategories** — drag a task from one subcategory and drop it onto a task in a different subcategory; task appears in destination.
4. **Move to an empty subcategory** — drag a task and drop onto the "Add a task…" zone of an empty subcategory; task moves there.
5. **Move to a different category** — drag a task from a subcategory and drop onto a direct item in a different category.
6. **Dragging item dims** — the row being dragged shows at 40% opacity.

---

### Task 6: Final commit

```bash
git add -A
git commit -m "feat: task drag-to-reorder with cross-container support"
```
