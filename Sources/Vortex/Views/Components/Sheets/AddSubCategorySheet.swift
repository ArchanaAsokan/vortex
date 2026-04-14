import SwiftUI

struct AddSubCategorySheet: View {
    let category: Category

    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .leading) {
                        if name.isEmpty {
                            Text("e.g. Project Alpha, Q1 Goals")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                        TextField("", text: $name)
                            .focused($focused)
                    }
                } header: {
                    Text("Sub-Category Name")
                } footer: {
                    Text("Will be added to \"\(category.name ?? "")\"")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Sub-Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 320, height: 180)
        .onAppear { focused = true }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let sub = SubCategory(context: context)
        sub.id = UUID()
        sub.name = trimmed
        sub.order = Int16(vm.subcategories(for: category).count)
        sub.isExpanded = true
        sub.createdAt = Date()
        sub.category = category
        PersistenceController.shared.save()
        dismiss()
    }
}
