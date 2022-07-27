//
//  EventSettingsViewController.swift
//  
//
//  Created by Kai on 2022/7/20.
//

import DiffableList
import EventKit

open class EventSettingsViewController: DiffableListViewController {
    lazy var eventStore = EKEventStore()
    
    open var isUserEnabled = false
    var isGranted = false
    
    var isEnabled: Bool {
        isUserEnabled && isGranted
    }
    
    var forceReloadToggleFlag = 0
    
    var status: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
    
    open override var list: DLList {
        DLList {
            DLSection { [unowned self] in
                DLCell {
                    DLText("开启")
                }
                .tag("enabling \(isEnabled) \(forceReloadToggleFlag)")
                .accessories([.toggle(isOn: isEnabled, action: { [unowned self] isOn in
                    if isOn {
                        determineAuthorizationStatus()
                    } else {
                        isUserEnabled = false
                        reload()
                    }
                })])
            }
            .tag("0")
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        isGranted = status == .authorized
        reload(animating: false)
    }
    
    open func openSystemSettings() {}
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
            .init(title: "去开启", style: .default, handler: { [unowned self] _ in
                openSystemSettings()
            })
        ])
        
        forceReloadToggleFlag += 1
        reload()
    }
}
