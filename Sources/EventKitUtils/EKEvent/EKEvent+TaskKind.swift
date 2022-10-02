//
//  EKEvent+TaskKind.swift
//
//
//  Created by Kai on 2022/7/20.
//

import EventKit

extension EKEvent: TaskKind {
    public var repeatingCount: Int? {
        get { nil }
        set {}
    }
    
    public var kindIdentifier: TaskKindIdentifier? {
        .event
    }
    
    public var isValueType: Bool {
        false
    }
    
    public var normalizedID: String {
        get {
            eventIdentifier
        }
        
        set {}
    }
    
    public var normalizedTitle: String {
        get { (title ?? "").statusEmojiTrimmed() }
        set {
            title = "\(emoji) \(newValue)"
            setValue(newValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), forKey: .title)
        }
    }
    
    public var normalizedStartDate: Date? {
        get { startDate }
        set { startDate = newValue }
    }
    
    public var normalizedEndDate: Date? {
        get { endDate }
        set { endDate = newValue }
    }
    
    public var originalIsAllDay: Bool {
        get { isAllDay }
        set { isAllDay = newValue }
    }
    
    public var premisedIsDateEnabled: Bool? { nil }
    
    public var isCompleted: Bool {
        get {
            completedAt != nil
        }
        
        set {
            completedAt = newValue ? Date() : nil
        }
    }
    
    public var abortedAt: Date? {
        get {
            guard let value = getValue(forKey: .abortedAt), let double = Double(value) else {
                return nil
            }
            
            return Date(timeIntervalSince1970: double)
        }
        
        set {
            setValue(newValue.map { String($0.timeIntervalSince1970) },
                     forKey: .abortedAt)
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
            setValue(newValue.map { String($0.timeIntervalSince1970) },
                     forKey: .completedAt)
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
            setValue(newValue, forKey: .keyResultId)
        }
    }
    
    public var linkedValue: Double? {
        get {
            guard let value = getValue(forKey: .linkedQuantity) else {
                return nil
            }
                
            return Double(value)
        }
        
        set {
            setValue(newValue.map { String($0) }, forKey: .linkedQuantity)
        }
    }
    
    public var createdAt: Date? {
        creationDate
    }
    
    public var updatedAt: Date? {
        lastModifiedDate
    }
    
    public func toggleCompletion() {
        isCompleted.toggle()
        normalizedTitle = normalizedTitle
    }
    
    public func updateVersion() {}
}

extension EKEvent {
    public convenience init(baseURL: URL, eventStore: EKEventStore) {
        self.init(eventStore: eventStore)
        self.url = baseURL
    }
}

extension String {
    func statusEmojiTrimmed() -> String {
        let trimedTitle = trimmingCharacters(in: .whitespacesAndNewlines)
        let signs = Set<Character>(["⭕️", "✅"])
        
        if let firstChar = trimedTitle.first,
           signs.contains(firstChar) {
            let newTitle = String(trimedTitle.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            
            return newTitle.statusEmojiTrimmed()
        }
        
        return trimedTitle
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
    
    func setValue(_ value: String?, forKey key: EventURLKeys) {
        setQueryItems(
            EventURLKeys.setValue(value, of: queryItems, forKey: key)
        )
    }
    
    func getValue(forKey key: EventURLKeys) -> String? {
        EventURLKeys.value(ofQueryItems: queryItems, forKey: key)
    }
    
    func setQueryItems(_ queryItems: [URLQueryItem]) {
        guard var urlComponents = urlComponents else {
            return
        }

        urlComponents.queryItems = queryItems
        url = urlComponents.url
    }
}
