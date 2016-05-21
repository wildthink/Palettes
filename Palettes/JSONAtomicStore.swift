//
//  JSONAtomicStore.swift
//  Created by Jason Jobe on 5/20/16.
//
//
import Cocoa

class JSONAtomicStore: NSAtomicStore {
    
    enum Error: ErrorType {
    case InvalidJSON
    case InaccessableURL
}
    var dateFormatter: NSDateFormatter
    
    private var cache = [NSManagedObjectID: AnyObject]()
    var localStorageURL: NSURL?
    var primaryKey: String = "_id"
    var entityKey: String = "_entity"
    
    class var storeType: String {
        return NSStringFromClass(JSONAtomicStore.self)
    }
    
    override class func initialize() {
        NSPersistentStoreCoordinator.registerStoreClass(self, forStoreType:self.storeType)
    }
    
    override init(persistentStoreCoordinator root: NSPersistentStoreCoordinator?, configurationName name: String?, URL url: NSURL, options: [NSObject : AnyObject]?) {
        self.localStorageURL = url
        dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        super.init(persistentStoreCoordinator: root, configurationName: name, URL: url, options: options)
    }
    // MARK: - NSIncrementalStore
    
    override func loadMetadata() throws {
        let uuid = NSProcessInfo.processInfo().globallyUniqueString
        self.metadata = [NSStoreTypeKey : JSONAtomicStore.storeType, NSStoreUUIDKey : uuid]
    }

    override func load() throws
    {
        guard let items = self.loadObjectsFromJSON() else { throw Error.InvalidJSON }
        for value in items {
            if let item = value as? [String: AnyObject] {
              cacheNodeForValues(item)
            }
        }
    }

    // MARK: - Private
    func createRelationship (relationship: NSRelationshipDescription, from subject: AnyObject, to object: AnyObject, includeInverse: Bool = true) {
        
        var key = relationship.name
    
        if relationship.toMany {
            var rel_object = subject.valueForKey (key)
            if var rel_object = subject.valueForKey (key) as? [AnyObject] {
                rel_object.append(object)
            } else {
                subject.setValue([object], forKey: key)
            }
        } else {
            subject.setValue(object, forKey: key)
        }

        guard includeInverse else { return }
        
        if let inverse = relationship.inverseRelationship {
            // NOTE: includeInverse MUST be false to avoid infinite recursion
            createRelationship(inverse, from: object, to: subject, includeInverse: false)
        }
    }

    func cacheNodeForValues (values: [String: AnyObject]) -> NSAtomicStoreCacheNode?
    {
        let entityName = values[entityKey]
        guard let entity = persistentStoreCoordinator?.managedObjectModel.entitiesByName[entityName] else { return }
        guard let referenceId = values[primaryKey] as? String else { return nil }
        let objectId = objectIDForEntity(entityDescription, referenceObject: referenceId)
        
        // Make sure we avoid creating duplicates
        if let found = self.cacheNodeForObjectID(objectId) { return found }
        
        var node = NSAtomicStoreCacheNode(objectID: objectId)
        
        var nodes = Set<NSAtomicStoreCacheNode>()

        nodes.insert(node)
        
        for (key, attr) in entityDescription.attributesByName {
            var value: AnyObject?
            guard let rawValue = values[key]?.description else { continue }
            
            switch attr.attributeType {
            case .DateAttributeType: value =  dateFormatter.dateFromString(rawValue)
            case .StringAttributeType: value = rawValue
            case .Integer16AttributeType: value = Int(rawValue)
            case .Integer32AttributeType: value = Int(rawValue)
            case .Integer64AttributeType: value = Int(rawValue)
            case .FloatAttributeType: value = Float(rawValue)
            case .DoubleAttributeType: value = Double(rawValue)
            case .DecimalAttributeType: value = NSDecimalNumber(string: rawValue, locale: nil)
            case .StringAttributeType: value = rawValue
            default:
                value = rawValue
                Swift.print ("\(attr.attributeType.rawValue) is PASS THRU")
            }
            node.setValue(value, forKey: key)
        }
        
        for (key, rel) in entityDescription.relationshipsByName
        {
            if let relation = values[key], let values = values[key] as? [String: AnyObject],
                let object = cacheNodeForValues(values)
            {
                nodes.insert(object)
                createRelationship (rel, from: node, to: object)
            }
        }

        self.addCacheNodes(nodes)
        return node
    }

    /**
     Loads object data from a local JSON file
     
     :returns: Array of object objects in dictionary form.
     */
    
    func loadObjectsFromJSON() -> throws [AnyObject]? {
        
        guard let localStorageURL = localStorageURL else { return nil }
        guard let data = NSData(contentsOfURL: localStorageURL) else { return throw Error.InvalidJSON }
        
        do {
            let results = NSJSONSerialization.JSONObjectWithData(data, options: [])
            guard let objects = results as? [NSDictionary] else {
                return nil
            }
            return objects
        }
        catch {
            print("error fetching objects: \(error)")
            throw Error.InvalidJSON
        }
    }
}
