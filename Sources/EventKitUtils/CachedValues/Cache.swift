//
//  File.swift
//  
//
//  Created by Kai on 2022/8/1.
//

import Foundation

public final class Cache<Key: Hashable, Value>: NSObject, NSCacheDelegate {
    private let wrapped = NSCache<WrappedKey, Entry>()
    
    override init() {
        super.init()
        wrapped.delegate = self
    }
    
    func insert(_ value: Value, forKey key: Key) {
        let entry = Entry(value: value)
        wrapped.setObject(entry, forKey: WrappedKey(key))
    }
    
    func value(forKey key: Key) -> Value? {
        wrapped.object(forKey: WrappedKey(key))?.value
    }
    
    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }
    
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        print("willEvictObject", obj)
        
    }
}

public extension Cache {
    subscript(key: Key) -> Value? {
        get {
            value(forKey: key)
        }
        
        set {
            guard let value = newValue else {
                removeValue(forKey: key)
                return
            }
            
            insert(value, forKey: key)
        }
    }
    
    func assignWithDictionary(_ dict: [Key: Value]) {
        wrapped.removeAllObjects()
        
        for (key, val) in dict {
            self[key] = val
        }
    }
}

private extension Cache {
    final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
        }
        
        override var hash: Int {
            key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else {
                return false
            }
            
            return value.key == key
        }
    }
}

private extension Cache {
    final class Entry {
        let value: Value
        
        init(value: Value) {
            self.value = value
        }
    }
}
