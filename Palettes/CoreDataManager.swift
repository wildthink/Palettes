//
//  CoreDataManager.swift
//  Ascent
//
//  Created by Andrew Shepard on 12/10/14.
//  Copyright (c) 2014 Andrew Shepard. All rights reserved.
//

import CoreData

class CoreDataManager: NSObject {
    
    // MARK: - Lifecycle
    
    static let sharedManager = CoreDataManager()
    
    override init() {
        super.init()
    }
    
    // MARK: - Core Data stack
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return managedObjectContext
    }()
    
    // MARK: - Public
    
    func fetchedResultsControllerForEntityName(name:String, sortDescriptors:Array<NSSortDescriptor>, predicate:NSPredicate! = nil) -> NSFetchedResultsController {
        let managedObjectContext = self.managedObjectContext
        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName(name, inManagedObjectContext: managedObjectContext!)
        
        fetchRequest.entity = entity
        fetchRequest.fetchBatchSize = 20
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try fetchedResultsController.performFetch()
        }
        catch (let error) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            print("Unresolved error: \(error)")
            abort()
        }
        
        return fetchedResultsController;
    }
    
    // MARK: - Private
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        let storeType = LocalIncrementalStore.storeType
//        let storeType = RemoteIncrementalStore.storeType
//        let storeType = CachingIncrementalStore.storeType
        
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = NSURL.applicationDocumentsDirectory().URLByAppendingPathComponent("Palettes.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: NSNumber(bool: true), NSInferMappingModelAutomaticallyOption: NSNumber(bool: true)];
        
        do {
           try coordinator!.addPersistentStoreWithType(storeType, configuration: nil, URL: url, options: options)
        }
        catch (let error as NSError) {
            if error.code == NSMigrationMissingMappingModelError {
                print("Error, migration failed. Delete model at \(url)")
            }
            else {
                print("Error creating persistent store: \(error.description)")
            }
            abort()
        }
        
        return coordinator
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle.mainBundle().URLForResource("Palettes", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
}
