# Task Drag-to-Reorder Design

**Date:** 2026-04-17
**Feature:** Drag-to-reorder for TodoItems, including cross-container moves

## Background

Vortex already supports drag-to-reorder for tabs and categories using SwiftUI's `onDrag`/`onDrop` + `DropDelegate` pattern. `TodoItem` already has an `order: Int16` Core Data field. This design extends the same pattern to tasks, adding cross-container moves (between subcategories and categories).

## Approach

Extend the existing `onDrag`/`onDrop` + `DropDelegate` pattern (same as `TabDropDelegate` and `CategoryDropDelegate`).

## Components

### `TodoViewModel`

- Add `@Published var draggingItem: TodoItem?` so all containers share drag state.
- Add `moveItem(_ item: TodoItem, before target: TodoItem, inCategory: Category?, inSubcategory: SubCategory?)`:
  - Update `item.category` and `item.subcategory` to the target's container (handles cross-container moves).
  - Compact `order` values in the source container (fill gaps left by the moved item).
  - Insert item before target in the destination container by shifting orders.
  - Save via `PersistenceController.shared.save()`.
- Add `appendItem(_ item: TodoItem, toCategory: Category?, toSubcategory: SubCategory?)` for dropping onto empty containers:
  - Update container relationships.
  - Set `item.order` to `max(existing orders) + 1`.
  - Save.

### `ItemDropDelegate`

New `DropDelegate` mirroring `CategoryDropDelegate`:

```
struct ItemDropDelegate: DropDelegate {
    let target: TodoItem
    let targetCategory: Category?
    let targetSubcategory: SubCategory?
    @Binding var dragging: TodoItem?
    let vm: TodoViewModel
}
```

- `dropEntered`: calls `vm.moveItem(dragging, before: target, inCategory:, inSubcategory:)`
- `performDrop`: sets `dragging = nil`, returns `true`
- `dropUpdated`: returns `DropProposal(operation: .move)`

### `TodoItemRow`

- Add `.onDrag { vm.draggingItem = item; return NSItemProvider(object: item.id!.uuidString as NSString) }`
- Add `.onDrop(of: [.plainText], delegate: ItemDropDelegate(...))` — delegate is constructed by the parent with the correct container context.
- Dim to opacity 0.4 when `vm.draggingItem?.id == item.id`.

### `CategoryRow`

- In the `ForEach(directItems)` loop, attach `.onDrag` and `.onDrop` to each `TodoItemRow`, passing `category` and `nil` as the container context.
- In the empty-state area, add an invisible `Color.clear` drop zone that calls `vm.appendItem(draggingItem, toCategory: category, toSubcategory: nil)` via a dedicated `ItemAppendDropDelegate`.

### `SubCategoryRow`

- Same as `CategoryRow` but passes `subcategory.category` and `subcategory` as container context.
- Add the same empty-state drop zone targeting the subcategory.

### `ItemAppendDropDelegate`

Handles drops onto empty containers:

```
struct ItemAppendDropDelegate: DropDelegate {
    let targetCategory: Category?
    let targetSubcategory: SubCategory?
    @Binding var dragging: TodoItem?
    let vm: TodoViewModel
}
```

- `performDrop`: calls `vm.appendItem(dragging, toCategory:, toSubcategory:)`, sets `dragging = nil`.

## Data Flow

1. User starts drag on a `TodoItemRow` → `vm.draggingItem` set, row dims.
2. User drags over another row → `dropEntered` fires → `vm.moveItem` updates Core Data order + relationships → view updates reactively.
3. User drops → `performDrop` fires → `vm.draggingItem = nil` → opacity restored.
4. If dropped on empty container drop zone → `vm.appendItem` assigns container and appends at end.

## Non-Goals

- Dragging tasks across tabs (only within the current tab's categories/subcategories).
- Animated reorder transitions (SwiftUI's reactive updates handle visual feedback).
