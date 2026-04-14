import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context

    @State private var showAddCategory = false
    @State private var showAddTab = false
    @State private var tabToRename: TodoTab? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Search + controls ────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))

                ZStack(alignment: .leading) {
                    if vm.searchText.isEmpty {
                        Text("Search tasks…")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 13))
                    }
                    TextField("", text: $vm.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 16)

                if vm.selectedTab != nil {
                    Button { showAddCategory = true } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("New Category")
                }

                Button {
                    vm.showCompleted.toggle()
                } label: {
                    Image(systemName: vm.showCompleted ? "eye" : "eye.slash")
                        .foregroundStyle(vm.showCompleted ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(vm.showCompleted ? "Hide completed tasks" : "Show completed tasks")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // ── Tab bar ──────────────────────────────────────
            let allTabs = vm.tabs()
            if !allTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(allTabs) { tab in
                            TabPill(
                                tab: tab,
                                isSelected: vm.selectedTab?.id == tab.id,
                                onSelect: { vm.selectedTab = tab },
                                onRename: { tabToRename = tab },
                                onDelete: {
                                    if vm.selectedTab?.id == tab.id {
                                        vm.selectedTab = allTabs.first(where: { $0.id != tab.id })
                                    }
                                    context.delete(tab)
                                    PersistenceController.shared.save()
                                }
                            )
                        }

                        // Add tab button
                        Button { showAddTab = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color.secondary.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("New Tab")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .background(.bar)

                Divider()
            }

            // ── Category list ────────────────────────────────
            if let tab = vm.selectedTab {
                let categories = vm.categories(for: tab)
                if categories.isEmpty && vm.searchText.isEmpty {
                    tabEmptyState(tab: tab)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(categories) { category in
                                CategoryRow(category: category)
                            }
                            Button {
                                showAddCategory = true
                            } label: {
                                Label("New Category", systemImage: "plus")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                noTabsEmptyState
            }
        }
        .frame(width: 360, height: 520)
        .onAppear { vm.selectFirstTabIfNeeded() }
        .sheet(isPresented: $showAddTab) {
            AddTabSheet()
                .environmentObject(vm)
                .environment(\.managedObjectContext, context)
        }
        .sheet(item: $tabToRename) { tab in
            AddTabSheet(editingTab: tab)
                .environmentObject(vm)
                .environment(\.managedObjectContext, context)
        }
        .sheet(isPresented: $showAddCategory) {
            if let tab = vm.selectedTab {
                AddCategorySheet(tab: tab)
                    .environmentObject(vm)
                    .environment(\.managedObjectContext, context)
            }
        }
    }

    private func tabEmptyState(tab: TodoTab) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No Categories in \"\(tab.name ?? "")\"")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add a category to start organising your tasks.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Add Category") { showAddCategory = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTabsEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No Tabs Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tabs are the top-level grouping.\nCreate one to get started.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Create Tab") { showAddTab = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Pill

private struct TabPill: View {
    let tab: TodoTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(tab.name ?? "")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") { onRename() }
            Divider()
            Button("Delete Tab", role: .destructive) { onDelete() }
        }
    }
}
