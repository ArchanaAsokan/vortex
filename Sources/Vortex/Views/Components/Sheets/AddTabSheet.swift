import SwiftUI

struct AddTabSheet: View {
    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context
    @Environment(\.dismiss) var dismiss

    var editingTab: TodoTab? = nil

    @State private var name = ""
    @FocusState private var focused: Bool

    private var isEditing: Bool { editingTab != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .leading) {
                        if name.isEmpty {
                            Text("e.g. Work, Personal, Shopping")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                        TextField("", text: $name)
                            .focused($focused)
                    }
                } header: {
                    Text("Tab Name")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Rename Tab" : "New Tab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 320, height: 160)
        .onAppear {
            if let tab = editingTab { name = tab.name ?? "" }
            focused = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let tab = editingTab {
            tab.name = trimmed
        } else {
            let tab = TodoTab(context: context)
            tab.id = UUID()
            tab.name = trimmed
            tab.order = Int16(vm.tabs().count)
            tab.createdAt = Date()
            vm.selectedTab = tab
        }

        PersistenceController.shared.save()
        dismiss()
    }
}
