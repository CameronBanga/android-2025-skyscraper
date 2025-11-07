//
//  CoreDataStack.swift
//  Skyscraper
//
//  Core Data stack for caching timeline posts
//

import Foundation
import CoreData

@MainActor
class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        // Create the model programmatically
        let model = createPostCacheModel()
        let container = NSPersistentContainer(name: "SkyscraperCache", managedObjectModel: model)

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // Check if this is a migration error
                if error.code == 134110 { // NSPersistentStoreIncompatibleVersionHashError or migration error
                    print("⚠️ Core Data migration failed - deleting old cache and starting fresh")

                    // Delete the old store file
                    if let storeURL = description.url {
                        do {
                            try FileManager.default.removeItem(at: storeURL)
                            // Also remove associated files
                            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
                            print("✅ Old cache deleted successfully")

                            // Try loading again with fresh store
                            container.loadPersistentStores { newDescription, newError in
                                if let newError = newError {
                                    print("❌ Core Data failed to load after cleanup: \(newError.localizedDescription)")
                                } else {
                                    print("✅ Core Data loaded successfully with fresh store")
                                }
                            }
                        } catch {
                            print("❌ Failed to delete old cache: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Core Data failed to load: \(error.localizedDescription)")
                }
            } else {
                print("Core Data loaded successfully")
            }
        }

        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private func createPostCacheModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create CachedPost entity
        let cachedPostEntity = NSEntityDescription()
        cachedPostEntity.name = "CachedPost"
        cachedPostEntity.managedObjectClassName = NSStringFromClass(CachedPost.self)

        // Attributes
        let uriAttr = NSAttributeDescription()
        uriAttr.name = "uri"
        uriAttr.attributeType = .stringAttributeType
        uriAttr.isOptional = false

        let jsonDataAttr = NSAttributeDescription()
        jsonDataAttr.name = "jsonData"
        jsonDataAttr.attributeType = .binaryDataAttributeType
        jsonDataAttr.isOptional = false

        let cachedAtAttr = NSAttributeDescription()
        cachedAtAttr.name = "cachedAt"
        cachedAtAttr.attributeType = .dateAttributeType
        cachedAtAttr.isOptional = false

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        let sortOrderAttr = NSAttributeDescription()
        sortOrderAttr.name = "sortOrder"
        sortOrderAttr.attributeType = .integer64AttributeType
        sortOrderAttr.isOptional = false

        let feedIdAttr = NSAttributeDescription()
        feedIdAttr.name = "feedId"
        feedIdAttr.attributeType = .stringAttributeType
        feedIdAttr.isOptional = false

        cachedPostEntity.properties = [uriAttr, jsonDataAttr, cachedAtAttr, createdAtAttr, sortOrderAttr, feedIdAttr]

        model.entities = [cachedPostEntity]

        return model
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving Core Data context: \(error.localizedDescription)")
            }
        }
    }

    func clearOldPosts(olderThan days: Int) {
        let context = persistentContainer.viewContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedPost")
        fetchRequest.predicate = NSPredicate(format: "cachedAt < %@", cutoffDate as NSDate)

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Deleted posts older than \(days) days")
        } catch {
            print("Error deleting old posts: \(error.localizedDescription)")
        }
    }
}

// Core Data managed object class
@objc(CachedPost)
class CachedPost: NSManagedObject {
    @NSManaged var uri: String
    @NSManaged var jsonData: Data
    @NSManaged var cachedAt: Date
    @NSManaged var createdAt: Date
    @NSManaged var sortOrder: Int64
    @NSManaged var feedId: String
}
