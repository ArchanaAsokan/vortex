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
        var predicates: [NSPredicate] = [NSPredicate(format: "category == %@", category)]
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
