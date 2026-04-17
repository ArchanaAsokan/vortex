import SwiftUI

struct CategoryRow: View {
    @ObservedObject var category: Category
    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context

    @State private var isExpanded: Bool
    @State private var isHovered = false
    @State private var showAddSubCategory = false
    @State private var showAddDirectItem = false

    init(category: Category) {
        self.category = category
        _isExpanded = State(initialValue: category.isExpanded)
    }

    private var subcategories: [SubCategory] { vm.subcategories(for: category) }
    private var directItems: [TodoItem] { vm.directItems(for: category) }

    var body: some View {
        if vm.searchText.isEmpty || vm.categoryHasVisibleItems(category) {
            VStack(spacing: 0) {
                // ── Category header ──────────────────────────
                HStack(spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                            category.isExpanded = isExpanded
                            PersistenceController.shared.save()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                    }
                    .buttonStyle(.plain)

                    Text(category.name ?? "")
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    if isHovered {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .help("Drag to reorder")

                        // Add Task directly to category
                        Button {
                            showAddDirectItem = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Add Task")

                        // Add Sub-Category
                        Button {
                            showAddSubCategory = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Add Sub-Category")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .contextMenu {
                    Button("Add Task") { showAddDirectItem = true }
                    Button("Add Sub-Category") { showAddSubCategory = true }
                    Divider()
                    Button("Delete Category", role: .destructive) {
                        context.delete(category)
                        PersistenceController.shared.save()
                    }
                }

                if isExpanded {
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

                    // ── Sub-categories ────────────────────────
                    ForEach(subcategories) { sub in
                        SubCategoryRow(subcategory: sub)
                            .padding(.leading, 8)
                    }

                    // Empty state — only when both direct items and subcategories are absent
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
                }

                Divider().opacity(0.5)
            }
            .sheet(isPresented: $showAddSubCategory) {
                AddSubCategorySheet(category: category)
                    .environmentObject(vm)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $showAddDirectItem) {
                TodoItemSheet(category: category)
                    .environmentObject(vm)
                    .environment(\.managedObjectContext, context)
            }
        }
    }
}
