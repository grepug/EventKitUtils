//
//  EventURLKeys.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import Foundation

public enum EventURLKeys {
    case keyResultId, linkedQuantity, completedAt
    
    public var key: String {
        switch self {
        case .keyResultId: return "k"
        case .linkedQuantity: return "v"
        case .completedAt: return "ca"
        }
    }
}

extension EventURLKeys {
    func value(ofQueryItems queryItems: [URLQueryItem]) -> String? {
        let value = queryItems.first { $0.name == key }?.value
        
        return value?.isEmpty == true ? nil : value
    }
    
    func setValue(_ value: String?, of queryItems: [URLQueryItem]) -> [URLQueryItem] {
        var queryItems = queryItems
        
        for (index, item) in queryItems.enumerated() {
            if item.name == key {
                queryItems[index] = .init(name: item.name, value: value)
                
                return queryItems
            }
        }
        
        queryItems.append(.init(name: key, value: value))
        
        return queryItems
    }
}
