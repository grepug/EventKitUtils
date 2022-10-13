//
//  EventSettingsViewController+Onboarding.swift
//  
//
//  Created by Kai Shao on 2022/10/13.
//

import UIKit
import SwiftUI

extension EventSettingsViewController {
    func presentOnboardingView() {
        let view = EventOnboardingView(isEnabled: isEnabled,
                                       isCollapsed: splitViewController?.isCollapsed != false) { [weak self] isOn in
            guard let self = self else { return }
            
            if isOn, !self.isEnabled {
                Task {
                    await self.handleToggleEnabled(isOn: true)
                }
            }
            
            self.dismiss(animated: true)
        }
        let vc = UIHostingController(rootView: view)
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }
    
    func makeOnbardingNavBarButton() -> UIBarButtonItem {
        .init(image: .init(systemName: "questionmark.circle"), primaryAction: .init { [weak self] _ in
            self?.presentOnboardingView()
        })
    }
}
