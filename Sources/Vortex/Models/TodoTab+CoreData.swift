import CoreData

@objc(TodoTab)
public class TodoTab: NSManagedObject {}

extension TodoTab {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TodoTab> {
        return NSFetchRequest<TodoTab>(entityName: "Tab")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var categories: NSSet?
}

extension TodoTab {
    @objc(addCategoriesObject:)
    @NSManaged public func addToCategories(_ value: Category)

    @objc(removeCategoriesObject:)
    @NSManaged public func removeFromCategories(_ value: Category)

    @objc(addCategories:)
    @NSManaged public func addToCategories(_ values: NSSet)

    @objc(removeCategories:)
    @NSManaged public func removeFromCategories(_ values: NSSet)
}

extension TodoTab: Identifiable {}
