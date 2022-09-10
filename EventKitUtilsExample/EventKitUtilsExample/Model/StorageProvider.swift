//
//  StorageProvider.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/24.
//

import StorageProvider
import CoreData

extension StorageProvider {
    static let shared = StorageProvider(storeDescriptionConfigurations: storeDescriptions,
                                        modelName: StorageProvider.modelName,
                                        iCloudEnabled: false)
    
    static var storeDescriptions: [StoreDescriptionConfiguration] {
        [
            .init(url: .appGroup(appGroupIdentifier: .APP_GROUP_NAME, dataBaseName: "eventKitUtilsDB"))
        ]
    }
    
    static var viewContext: NSManagedObjectContext {
        Self.shared.persistentContainer.viewContext
    }
}

fileprivate extension StorageProvider {
    static let modelName = "EventKitUtils"
}

extension String {
    static let APP_GROUP_NAME = "group.visionapp.vision"
}

extension SimpleManagedObject {
    public static var viewContext: NSManagedObjectContext {
        StorageProvider.viewContext
    }
    
    public static func newBackgroundContext() -> NSManagedObjectContext {
        StorageProvider.shared.persistentContainer.newBackgroundContext()
    }
}
