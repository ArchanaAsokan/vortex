import CoreData
import Combine
import SwiftUI

final class TodoViewModel: ObservableObject {
    @Published var showCompleted: Bool
    @Published var searchText: String = ""
    @Published var selectedTab: TodoTab?

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
        self.showCompleted = UserDefaults.standard.bool(forKey: "vortex.showCompleted")

        $showCompleted
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "vortex.showCompleted") }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSManagedObjectContext.didChangeObjectsNotification,
            object: context
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)

        migrateOrphanedCategories()
    }

    // MARK: - Migration

    /// On first launch after adding tabs, assign any un-tabbed categories to a default tab.
    private func migrateOrphanedCategories() {
        let req = Category.fetchRequest()
        req.predicate = NSPredicate(format: "tab == nil")
        guard let orphans = try? context.fetch(req), !orphans.isEmpty else { return }

        // Find or create a "General" tab
        let tabReq = TodoTab.fetchRequest()
        tabReq.predicate = NSPredicate(format: "name == %@", "General")
        let generalTab: TodoTab
        if let existing = (try? context.fetch(tabReq))?.first {
            generalTab = existing
        } else {
            generalTab = TodoTab(context: context)
            generalTab.id = UUID()
            generalTab.name = "General"
            generalTab.order = 0
            generalTab.createdAt = Date()
        }

        for category in orphans {
            category.tab = generalTab
        }
        try? context.save()

        // Select General tab if nothing selected
        if selectedTab == nil {
            selectedTab = generalTab
        }
    }

    // MARK: - Tab helpers

    func tabs() -> [TodoTab] {
        let req = TodoTab.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    func selectFirstTabIfNeeded() {
        guard selectedTab == nil else { return }
        selectedTab = tabs().first
    }

    // MARK: - Category helpers

    func categories(for tab: TodoTab) -> [Category] {
        let req = Category.fetchRequest()
        req.predicate = NSPredicate(format: "tab == %@", tab)
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    func subcategories(for category: Category) -> [SubCategory] {
        let req = SubCategory.fetchRequest()
        req.predicate = NSPredicate(format: "category == %@", category)
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    /// Items belonging directly to a category (no sub-category).
    func directItems(for category: Category) -> [TodoItem] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "category == %@", category),
            NSPredicate(format: "subcategory == nil")
        ]
        if !showCompleted {
            predicates.append(NSPredicate(format: "isCompleted == NO"))
        }
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", searchText))
        }
        let req = TodoItem.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    /// Items belonging to a sub-category.
    func items(for subcategory: SubCategory) -> [TodoItem] {
        var predicates: [NSPredicate] = [NSPredicate(format: "subcategory == %@", subcategory)]
        if !showCompleted {
            predicates.append(NSPredicate(format: "isCompleted == NO"))
        }
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", searchText))
        }
        let req = TodoItem.fetchRequest()
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    func pendingCount() -> Int {
        let req = TodoItem.fetchRequest()
        req.predicate = NSPredicate(format: "isCompleted == NO")
        return (try? context.count(for: req)) ?? 0
    }

    // MARK: - Visibility helpers for search

    func subcategoryHasVisibleItems(_ subcategory: SubCategory) -> Bool {
        !items(for: subcategory).isEmpty
    }

    func categoryHasVisibleItems(_ category: Category) -> Bool {
        !directItems(for: category).isEmpty ||
        subcategories(for: category).contains { subcategoryHasVisibleItems($0) }
    }

    // MARK: - Reorder helpers

    func moveTab(_ tab: TodoTab, before target: TodoTab) {
        var ordered = tabs()
        guard let fromIdx = ordered.firstIndex(of: tab),
              let _ = ordered.firstIndex(of: target),
              tab != target else { return }
        ordered.remove(at: fromIdx)
        guard let newTargetIdx = ordered.firstIndex(of: target) else { return }
        ordered.insert(tab, at: newTargetIdx)
        for (i, t) in ordered.enumerated() { t.order = Int16(i) }
        PersistenceController.shared.save()
    }

    func moveCategory(_ category: Category, before target: Category, in tab: TodoTab) {
        var ordered = categories(for: tab)
        guard let fromIdx = ordered.firstIndex(of: category),
              let _ = ordered.firstIndex(of: target),
              category != target else { return }
        ordered.remove(at: fromIdx)
        guard let newTargetIdx = ordered.firstIndex(of: target) else { return }
        ordered.insert(category, at: newTargetIdx)
        for (i, c) in ordered.enumerated() { c.order = Int16(i) }
        PersistenceController.shared.save()
    }

    func moveItem(_ item: TodoItem, before target: TodoItem,
                  toCategory: Category?, toSubcategory: SubCategory?) {
        // Save source container before re-assigning relationships
        let sourceCategory = item.category
        let sourceSubcategory = item.subcategory

        // Collect items in the destination container (excluding the dragged item)
        let destItems = itemsInContainer(category: toCategory, subcategory: toSubcategory)
            .filter { $0 != item }

        // Find insertion index
        guard let targetIdx = destItems.firstIndex(of: target) else { return }

        // Re-assign container relationships (subcategory items must not also set category)
        item.subcategory = toSubcategory
        item.category = toSubcategory == nil ? toCategory : nil

        // Build new ordered list and assign order values
        var newOrder = destItems
        newOrder.insert(item, at: targetIdx)
        for (i, t) in newOrder.enumerated() { t.order = Int16(i) }

        // Compact source container if it changed
        if sourceCategory != toCategory || sourceSubcategory != toSubcategory {
            compactOrder(category: sourceCategory, subcategory: sourceSubcategory)
        }

        PersistenceController.shared.save()
    }

    func appendItem(_ item: TodoItem,
                    toCategory: Category?, toSubcategory: SubCategory?) {
        let sourceCategory = item.category
        let sourceSubcategory = item.subcategory

        let existing = itemsInContainer(category: toCategory, subcategory: toSubcategory)
            .filter { $0 != item }
        item.subcategory = toSubcategory
        item.category = toSubcategory == nil ? toCategory : nil
        item.order = Int16((existing.last.map { Int($0.order) } ?? -1) + 1)

        if sourceCategory != toCategory || sourceSubcategory != toSubcategory {
            compactOrder(category: sourceCategory, subcategory: sourceSubcategory)
        }

        PersistenceController.shared.save()
    }

    // Returns all items in a container regardless of showCompleted/search filters
    private func itemsInContainer(category: Category?, subcategory: SubCategory?) -> [TodoItem] {
        let req = TodoItem.fetchRequest()
        if let sub = subcategory {
            req.predicate = NSPredicate(format: "subcategory == %@", sub)
        } else if let cat = category {
            req.predicate = NSPredicate(format: "category == %@ AND subcategory == nil", cat)
        } else {
            return []
        }
        req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true),
                               NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    private func compactOrder(category: Category?, subcategory: SubCategory?) {
        let orderedItems = itemsInContainer(category: category, subcategory: subcategory)
        for (i, item) in orderedItems.enumerated() { item.order = Int16(i) }
    }

    // MARK: - Count helpers

    func directItemCount(for category: Category) -> Int {
        let req = TodoItem.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "category == %@", category)]
        if !showCompleted {
            predicates.append(NSPredicate(format: "isCompleted == NO"))
        }
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return (try? context.count(for: req)) ?? 0
    }
}
