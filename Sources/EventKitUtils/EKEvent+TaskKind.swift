//
//  EKEvent+TaskKind.swift
//
//
//  Created by Kai on 2022/7/20.
//

import EventKit

extension EKEvent: TaskKind {
    public var id: String {
        calendarItemIdentifier
    }
    
    public var normalizedTitle: String {
        get { title ?? "" }
        set { title = newValue }
    }
    
    public var normalizedStartDate: Date? {
        get { startDate }
        set { startDate = newValue }
    }
    
    public var normalizedEndDate: Date? {
        get { endDate }
        set { endDate = newValue }
    }
    
    public var isCompleted: Bool {
        get {
            getValue(forKey: .isCompleted) == "1"
        }
        
        set {
            setValue(newValue ? "1" : "0", forKey: .isCompleted)
        }
    }
    
    public var completedAt: Date? {
        get {
            guard let value = getValue(forKey: .completedAt), let double = Double(value) else {
                return nil
            }
            
            return Date(timeIntervalSince1970: double)
        }
        
        set {
            var value: String = ""
            
            if let date = newValue {
                value = String(date.timeIntervalSince1970)
            }
            
            setValue(value, forKey: .completedAt)
        }
    }
    
    public var keyResultId: String? {
        get {
            guard let value = getValue(forKey: .keyResultId) else {
                return nil
            }
            
            return value
        }
        
        set {
            guard let value = newValue else {
                return
            }
            
            setValue(value, forKey: .keyResultId)
        }
    }
    
    public var linkedQuantity: Int? {
        get {
            guard let value = getValue(forKey: .linkedQuantity) else {
                return nil
            }
                
            return Int(value)
        }
        
        set {
            setValue(newValue.map { String($0) } ?? "", forKey: .linkedQuantity)
        }
    }
    
    public var createdAt: Date? {
        creationDate
    }
    
    public var updatedAt: Date? {
        lastModifiedDate
    }
    
    public func toggleCompletion() {
        if !isCompleted {
            setValue("\(Date().timeIntervalSince1970)", forKey: .completedAt)
        } else {
            setValue("", forKey: .completedAt)
        }
        
        isCompleted.toggle()
    }
    
    public var cellTag: String {
        ""
    }
}

extension EKEvent {
    public convenience init(baseURL: URL, eventStore: EKEventStore) {
        self.init(eventStore: eventStore)
        
        let urlComponents = URLComponents(string: baseURL.absoluteString)!
        self.url = urlComponents.url
    }
}

private extension EKEvent {
    var urlComponents: URLComponents? {
        url.map { url in
            URLComponents(string: url.absoluteString)!
        }
    }
    
    var queryItems: [URLQueryItem] {
        urlComponents?.queryItems ?? []
    }
    
    func setValue(_ value: String, forKey key: EventURLKeys) {
        setQueryItems(
            key.setValue(value, of: queryItems)
        )
    }
    
    func getValue(forKey key: EventURLKeys) -> String? {
        key.value(ofQueryItems: queryItems)
    }
    
    func setQueryItems(_ queryItems: [URLQueryItem]) {
        guard var urlComponents = urlComponents else {
            return
        }

        urlComponents.queryItems = queryItems
        url = urlComponents.url
    }
}
