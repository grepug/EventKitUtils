//
//  EventURLKeys.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public enum EventURLKeys {
    case keyResultId, linkedQuantity, completedAt, title, abortedAt
    
    public var name: String {
        switch self {
        case .keyResultId: return "k"
        case .linkedQuantity: return "v"
        case .completedAt: return "ca"
        case .title: return "t"
        case .abortedAt: return "ab"
        }
    }
}

extension EventURLKeys {
    public static func value(ofQueryItems queryItems: [URLQueryItem], forKey key: EventURLKeys) -> String? {
        let value = queryItems.first { $0.name == key.name }?.value
        
        return value?.isEmpty == true ? nil : value
    }
    
    static func setValue(_ value: String?, of queryItems: [URLQueryItem], forKey key: EventURLKeys) -> [URLQueryItem] {
        var queryItems = queryItems
        
        for (index, item) in queryItems.enumerated() {
            if item.name == key.name {
                queryItems[index] = .init(name: item.name, value: value)
                
                return queryItems
            }
        }
        
        queryItems.append(.init(name: key.name, value: value))
        
        return queryItems
    }
}
