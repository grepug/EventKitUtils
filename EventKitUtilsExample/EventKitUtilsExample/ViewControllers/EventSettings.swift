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
}
