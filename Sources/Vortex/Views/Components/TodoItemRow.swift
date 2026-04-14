import SwiftUI

struct TodoItemRow: View {
    @ObservedObject var item: TodoItem
    @EnvironmentObject var vm: TodoViewModel
    @Environment(\.managedObjectContext) var context
    @State private var isHovered = false
    @State private var showEditSheet = false

    private var priorityColor: Color? {
        guard item.hasPriority else { return nil }
        switch item.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return nil
        }
    }

    private var isOverdue: Bool {
        guard item.hasDueDate, let d = item.dueDate else { return false }
        return !item.isCompleted && d < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 8) {
            // Priority dot — always reserves space for alignment
            Circle()
                .fill(priorityColor ?? Color.clear)
                .frame(width: 7, height: 7)

            // Completion toggle
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    item.isCompleted.toggle()
                    item.completedAt = item.isCompleted ? Date() : nil
                    PersistenceController.shared.save()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? Color.green : Color.secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)

            // Title + optional due date
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "")
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)

                if item.hasDueDate, let date = item.dueDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(date, style: .date)
                            .font(.caption2)
                    }
                    .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.1) : Color.clear)
        )
        .opacity(item.isCompleted ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit") { showEditSheet = true }
            Divider()
            Button("Delete", role: .destructive) {
                context.delete(item)
                PersistenceController.shared.save()
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TodoItemSheet(subcategory: item.subcategory, category: item.category, editingItem: item)
                .environmentObject(vm)
                .environment(\.managedObjectContext, context)
        }
    }
}
