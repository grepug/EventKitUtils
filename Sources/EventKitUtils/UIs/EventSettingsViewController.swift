//
//  EventSettingsViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import EventKit
import UIKit



open class EventSettingsViewController: DiffableListViewController {
    lazy var eventStore = EKEventStore()
    var calendars: [EKCalendar] = []
    
    var isGranted = false
    var forceReloadToggleFlag = 0
    
    var isEnabled: Bool {
        isGranted
    }
    
    var status: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
    
    open override var list: DLList {
        DLList { [unowned self] in
            DLSection { [unowned self] in
                DLCell {
                    DLText("开启")
                }
                .tag("enabling \(isEnabled) \(forceReloadToggleFlag)")
                .accessories([.toggle(isOn: isEnabled, action: { [unowned self] isOn in
                    if isOn {
                        determineAuthorizationStatus()
                    } else {
                        Self.openSettings()
                        
                        forceReloadToggleFlag += 1
                        reload()
                    }
                })])
            }
            .tag("0")
            
            if isEnabled {
                DLSection { [unowned self] in
                    DLCell(using: .header("默认日历", using: .groupedHeader()))
                        .tag("header")
                    
                    for calendar in calendars {
                        let selected = isCalendarSelected(calendar)
                        
                        DLCell { [unowned self] in
                            DLImage(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .color(UIColor(cgColor: calendar.cgColor))
                            DLText(calendar.title)
                            
                            if self.eventStore.defaultCalendarForNewEvents == calendar {
                                DLText("系统默认")
                                    .secondary()
                                    .color(.secondaryLabel)
                            }
                        }
                        .tag(calendar.calendarIdentifier + "\(selected)")
                        .onTapAndDeselect { [unowned self] _ in
                            EventManager.selectedCalendarIdentifier = calendar.calendarIdentifier
                            reload()
                        }
                    }
                }
                .tag("calendars")
                .firstCellAsHeader()
            }
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "日历任务"
        
        setTopPadding()
        isGranted = status == .authorized
        calendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
        
        reload(animating: false)
    }
    
    func isCalendarSelected(_ calendar: EKCalendar) -> Bool {
        calendar.calendarIdentifier == EventManager.selectedCalendarIdentifier ?? eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    }
}

extension EventSettingsViewController {
    func determineAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            requestAccess()
        case .denied, .restricted:
            presentGoingToSystemSettingsAlert()
        case .authorized:
            isGranted = true
        @unknown default:
            presentGoingToSystemSettingsAlert()
        }
    }
    
    func requestAccess() {
        eventStore.requestAccess(to: .event) { [unowned self] isGranted, error in
            if error != nil {
                self.isGranted = false
            } else {
                self.isGranted = isGranted
            }
        }
    }
    
    func presentGoingToSystemSettingsAlert() {
        presentAlertController(title: "未授权日历访问", message: "去系统设置开启日历访问权限", actions: [
            .cancel,
            .init(title: "去开启", style: .default, handler: { _ in
                Self.openSettings()
            })
        ])
        
        forceReloadToggleFlag += 1
        reload()
    }
}

extension EventSettingsViewController {
    static func openSettings() {
        let url: URL
        #if targetEnvironment(macCatalyst)
        url = Self.macOSCalendarPrivacyURL
        #else
        url = URL(string: UIApplication.openSettingsURLString)!
        #endif

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    static var macOSCalendarPrivacyURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
    }
}
