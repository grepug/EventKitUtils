//
//  EventSettings.swift
//  EventKitUtilsExample
//
//  Created by Kai on 2022/7/27.
//

import EventKitUtils
import UIKit

class EventSettings: EventSettingsViewController {
    override var isUserEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isUserEnabledEventKit") }
        set { UserDefaults.standard.set(newValue, forKey: "isUserEnabledEventKit") }
    }
    
    override func openSystemSettings() {
        Utils.openSettings()
    }
}

struct Utils {
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
    
    static func delay(for delayed: Double = 0, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .init(delayed)) {
            action()
        }
    }
}
