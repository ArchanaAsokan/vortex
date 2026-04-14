import CoreData

@objc(Category)
public class Category: NSManagedObject {}

extension Category {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var order: Int16
    @NSManaged public var isExpanded: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var tab: TodoTab?
    @NSManaged public var subcategories: NSSet?
    @NSManaged public var directItems: NSSet?
}

extension Category {
    @objc(addSubcategoriesObject:)
    @NSManaged public func addToSubcategories(_ value: SubCategory)

    @objc(removeSubcategoriesObject:)
    @NSManaged public func removeFromSubcategories(_ value: SubCategory)

    @objc(addSubcategories:)
    @NSManaged public func addToSubcategories(_ values: NSSet)

    @objc(removeSubcategories:)
    @NSManaged public func removeFromSubcategories(_ values: NSSet)

    @objc(addDirectItemsObject:)
    @NSManaged public func addToDirectItems(_ value: TodoItem)

    @objc(removeDirectItemsObject:)
    @NSManaged public func removeFromDirectItems(_ value: TodoItem)

    @objc(addDirectItems:)
    @NSManaged public func addToDirectItems(_ values: NSSet)

    @objc(removeDirectItems:)
    @NSManaged public func removeFromDirectItems(_ values: NSSet)
}

extension Category: Identifiable {}
