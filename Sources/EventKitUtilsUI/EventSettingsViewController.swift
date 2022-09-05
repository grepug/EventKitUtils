//
//  EventSettingsViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import EventKit
import UIKit
import UIKitUtils
import EventKitUtils
import SwiftUI
import Combine

public class EventSettingsViewController: DiffableListViewController {
    unowned let em: EventManager
    var calendars: [EKCalendar] = []
    
    var isGranted = false
    var forceReloadToggleFlag = 0
    
    var isEnabled: Bool {
        isGranted
    }
    
    var store: EKEventStore {
        em.eventStore
    }
    
    var status: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
    
    var cancellables = Set<AnyCancellable>()
    
    public init(eventManager: EventManager) {
        self.em = eventManager
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        print("deinit EventSettings")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var list: DLList {
        DLList { [unowned self] in
            DLSection { [unowned self] in
                DLCell {
                    DLText("event_settings_enable".loc)
                }
                .tag("enabling \(isEnabled) \(forceReloadToggleFlag)")
                .accessories([.toggle(isOn: isEnabled, action: { [unowned self] isOn in
                    Task {
                        await handleToggle(isOn: isOn)
                    }
                })])
            }
            .tag("0")
            .footer("event_settings_enable_footer".loc)
            
            if isEnabled {
                DLSection { [unowned self] in
                    DLCell(using: .swiftUI(movingTo: self, content: {
                        VStack(alignment: .leading) {
                            Text("event_settings_select_default_calendar".loc)
                                .font(.title2.bold())
                                .padding(.bottom, 2)
                            Text("event_settings_select_default_calendar_desc".loc)
                                .font(.footnote)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding([.bottom, .leading])
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }))
                    .tag("header")
                    
                    for calendar in self.calendars {
                        let selected = isCalendarSelected(calendar)
                        
                        DLCell { [unowned self] in
                            DLImage(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .color(UIColor(cgColor: calendar.cgColor))
                            DLText(calendar.title)
                            
                            if self.store.defaultCalendarForNewEvents == calendar {
                                DLText("event_settings_default_calendar_desc".loc)
                                    .secondary()
                                    .color(.secondaryLabel)
                            }
                        }
                        .tag(calendar.calendarIdentifier + "\(selected)")
                        .onTapAndDeselect { [unowned self] _ in
                            em.selectedCalendarIdentifier = calendar.calendarIdentifier
                            reload()
                        }
                    }
                }
                .tag("calendars")
                .firstCellAsHeader()
                .footer("event_settings_sync_notice".loc)
            }
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "event_settings_title".loc
        
        setTopPadding()
        setCalendars(store: store)
        reload(animating: false)
        
        if presentingViewController != nil {
            navigationItem.rightBarButtonItem = makeDoneButton { [unowned self] in
                presentingViewController?.dismiss(animated: true)
            }
        }
    }
    
    public override func reload(applyingSnapshot: Bool = true, animating: Bool = true, options: Set<DiffableListViewController.ReloadingOption> = []) {
        forceReloadToggleFlag += 1
        isGranted = status == .authorized
        
        super.reload(applyingSnapshot: applyingSnapshot, animating: animating, options: options)
    }
    
    func isCalendarSelected(_ calendar: EKCalendar) -> Bool {
        calendar.calendarIdentifier == em.selectedCalendarIdentifier ??
        store.defaultCalendarForNewEvents?.calendarIdentifier
    }
    
    func handleToggle(isOn: Bool) async {
        guard isOn else {
            Self.openSettings()
            reload()
            return
        }
        
        await determineAuthorizationStatus()
    }
}

extension EventSettingsViewController {
    func setCalendars(store: EKEventStore) {
        calendars = store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted(by: {
                $0.title > $1.title
            })
    }
    
    @MainActor
    func determineAuthorizationStatus() async {
        switch status {
        case .notDetermined:
            await requestAccess()
        case .denied, .restricted:
            presentGoingToSystemSettingsAlert()
        case .authorized:
            isGranted = true
            reload()
        @unknown default:
            presentGoingToSystemSettingsAlert()
        }
    }

    @MainActor
    func requestAccess() async {
        let store = EKEventStore()
        
        do {
            let res = try await store.requestAccess(to: .event)
            setCalendars(store: store)
            isGranted = res
            em.eventStore = store
        } catch {
            isGranted = false
        }
        
        reload()
    }
    
    func presentGoingToSystemSettingsAlert() {
        presentAlertController(title: "event_settings_not_authorized_alert_title".loc, message: "event_settings_not_authorized_alert_msg".loc, actions: [
            .cancel,
            .init(title: "event_settings_not_authorized_alert_action".loc, style: .default, handler: { _ in
                Self.openSettings()
            })
        ])
        
        reload()
    }
}

extension EventSettingsViewController {
    static func openSettings() {
        let url: URL
        #if targetEnvironment(macCatalyst)
        url = macOSCalendarPrivacyURL
        #else
        url = URL(string: UIApplication.openSettingsURLString)!
        #endif

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    #if targetEnvironment(macCatalyst)
    static var macOSCalendarPrivacyURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
    }
    #endif
}
