//
//  EKEvent+TaskKind.swift
//
//
//  Created by Kai on 2022/7/20.
//

import EventKit

extension EKEvent: TaskKind {
    public var kindIdentifier: TaskKindIdentifier {
        .event
    }
    
    public var normalizedID: String {
        eventIdentifier
    }
    
    var titlePrefixEmoji: String {
        isCompleted ? "✅" : "⭕️"
    }
    
    public var normalizedTitle: String {
        get { (title ?? "").statusEmojiTrimmed() }
        set { title = "\(titlePrefixEmoji) \(newValue)" }
    }
    
    public var normalizedStartDate: Date? {
        get { startDate }
        set { startDate = newValue }
    }
    
    public var normalizedEndDate: Date? {
        get {
            if isAllDay {
                return endDate.endOfDay
            }
            
            return endDate
        }
        set { endDate = newValue }
    }
    
    public var isCompleted: Bool {
        get {
            completedAt != nil
        }
        
        set {
            completedAt = newValue ? Date() : nil
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
    
    public var linkedValue: Double? {
        get {
            guard let value = getValue(forKey: .linkedQuantity) else {
                return nil
            }
                
            return Double(value)
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
        isCompleted.toggle()
        normalizedTitle = normalizedTitle
    }
            
    public func copy(from task: TaskKind) {
        normalizedTitle = task.normalizedTitle
        normalizedStartDate = task.normalizedStartDate
        normalizedEndDate = task.normalizedEndDate
        isAllDay = task.isAllDay
        isCompleted = task.isCompleted
        completedAt = task.completedAt
        notes = task.notes
        keyResultId = task.keyResultId
        linkedValue = task.linkedValue
    }
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
