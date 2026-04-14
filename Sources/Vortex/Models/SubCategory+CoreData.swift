import CoreData

@objc(SubCategory)
public class SubCategory: NSManagedObject {}

extension SubCategory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubCategory> {
        return NSFetchRequest<SubCategory>(entityName: "SubCategory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var isExpanded: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var category: Category?
    @NSManaged public var items: NSSet?
}

extension SubCategory {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: TodoItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: TodoItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

extension SubCategory: Identifiable {}
