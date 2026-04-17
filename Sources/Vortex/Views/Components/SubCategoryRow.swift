import SwiftUI

struct SubCategoryRow: View {
    @ObservedObject var subcategory: SubCategory
    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context

    @Binding var draggingItem: TodoItem?

    @State private var isExpanded: Bool
    @State private var isHovered = false
    @State private var showAddItem = false

    init(subcategory: SubCategory, draggingItem: Binding<TodoItem?>) {
        self.subcategory = subcategory
        self._draggingItem = draggingItem
        _isExpanded = State(initialValue: subcategory.isExpanded)
    }

    private var visibleItems: [TodoItem] { vm.items(for: subcategory) }

    var body: some View {
        // Hide when searching and no visible items
        if vm.searchText.isEmpty || !visibleItems.isEmpty {
            VStack(spacing: 0) {
                // Sub-category header
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                            subcategory.isExpanded = isExpanded
                            PersistenceController.shared.save()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)

                    Text(subcategory.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if !isExpanded {
                        let count = vm.items(for: subcategory).count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }

                    Spacer()

                    if isHovered || showAddItem {
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Add Task")
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(isHovered ? Color.secondary.opacity(0.06) : Color.clear)
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .contextMenu {
                    Button("Add Task") { showAddItem = true }
                    Divider()
                    Button("Delete Sub-Category", role: .destructive) {
                        context.delete(subcategory)
                        PersistenceController.shared.save()
                    }
                }

                // Task rows
                if isExpanded {
                    if visibleItems.isEmpty {
                        ZStack {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .onDrop(
                                    of: [.plainText],
                                    delegate: ItemAppendDropDelegate(
                                        targetCategory: subcategory.category,
                                        targetSubcategory: subcategory,
                                        dragging: $draggingItem,
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
                    } else {
                        ForEach(visibleItems) { item in
                            TodoItemRow(item: item)
                                .padding(.leading, 16)
                                .opacity(draggingItem?.id == item.id ? 0.4 : 1.0)
                                .onDrag {
                                    draggingItem = item
                                    return NSItemProvider(object: (item.id?.uuidString ?? "") as NSString)
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: ItemDropDelegate(
                                        target: item,
                                        targetCategory: subcategory.category,
                                        targetSubcategory: subcategory,
                                        dragging: $draggingItem,
                                        vm: vm
                                    )
                                )
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                TodoItemSheet(subcategory: subcategory)
                    .environmentObject(vm)
                    .environment(\.managedObjectContext, context)
            }
        }
    }
}
