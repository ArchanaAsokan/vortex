import CoreData

@objc(TodoItem)
public class TodoItem: NSManagedObject {}

extension TodoItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TodoItem> {
        return NSFetchRequest<TodoItem>(entityName: "TodoItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var hasDueDate: Bool
    @NSManaged public var hasPriority: Bool
    @NSManaged public var priority: Int16
    @NSManaged public var order: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var subcategory: SubCategory?
    @NSManaged public var category: Category?
}

extension TodoItem: Identifiable {}
