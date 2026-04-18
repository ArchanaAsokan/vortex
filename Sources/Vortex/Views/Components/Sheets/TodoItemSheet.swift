import SwiftUI

struct TodoItemSheet: View {
    /// Provide exactly one of these (or editingItem to edit an existing item).
    var subcategory: SubCategory? = nil
    var category: Category? = nil
    var editingItem: TodoItem? = nil

    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var priorityEnabled = false
    @State private var priority: Int16 = 2
    @State private var dueDateEnabled = false
    @State private var dueDate = Date()
    @FocusState private var titleFocused: Bool

    private var isEditing: Bool { editingItem != nil }

    private var parentLabel: String {
        if let sub = subcategory { return sub.name ?? "" }
        if let cat = category { return cat.name ?? "" }
        return ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .leading) {
                        if title.isEmpty {
                            Text("What needs to be done?")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                        TextField("", text: $title)
                            .focused($titleFocused)
                            .multilineTextAlignment(.leading)
                    }
                } header: {
                    Text("Task")
                } footer: {
                    if !parentLabel.isEmpty && !isEditing {
                        Text("Adding to \"\(parentLabel)\"")
                    }
                }

                Section("Priority") {
                    Toggle("Set Priority", isOn: $priorityEnabled)
                    if priorityEnabled {
                        Picker("Level", selection: $priority) {
                            HStack {
                                Circle().fill(Color.blue).frame(width: 8, height: 8)
                                Text("Low")
                            }.tag(Int16(1))
                            HStack {
                                Circle().fill(Color.orange).frame(width: 8, height: 8)
                                Text("Medium")
                            }.tag(Int16(2))
                            HStack {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("High")
                            }.tag(Int16(3))
                        }
                        .pickerStyle(.radioGroup)
                    }
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $dueDateEnabled)
                    if dueDateEnabled {
                        DatePicker(
                            "Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 360, height: 400)
        .onAppear {
            if let item = editingItem {
                title = item.title ?? ""
                priorityEnabled = item.hasPriority
                priority = item.hasPriority ? item.priority : 2
                dueDateEnabled = item.hasDueDate
                dueDate = item.dueDate ?? Date()
            }
            titleFocused = true
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let item = editingItem ?? TodoItem(context: context)
        if editingItem == nil {
            item.id = UUID()
            item.createdAt = Date()
            item.isCompleted = false

            if let sub = subcategory {
                item.subcategory = sub
                item.category = nil
                item.order = Int16(vm.items(for: sub).count)
            } else if let cat = category {
                item.category = cat
                item.subcategory = nil
                item.order = Int16(vm.directItems(for: cat).count)
            }
        }

        item.title = trimmed
        item.hasPriority = priorityEnabled
        item.priority = priorityEnabled ? priority : 0
        item.hasDueDate = dueDateEnabled
        item.dueDate = dueDateEnabled ? dueDate : nil

        PersistenceController.shared.save()
        dismiss()
    }
}
