//
//  EventOnboardingView.swift
//  
//
//  Created by Kai Shao on 2022/10/13.
//

import SwiftUI

struct EventOnboardingView: View {
    var isEnabled: Bool
    var isCollapsed: Bool
    var action: (Bool) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                content
            }
            .frame(maxWidth: .infinity)
            
            Button {
                action(false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .offset(x: -24, y: 24)
        }
    }
    
    var content: some View {
        VStack {
            VStack(spacing: 24) {
                Image(systemName: "")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 56))
                Text("event_settings_onboarding_title".loc)
                    .font(.largeTitle.bold())
            }
            .padding(.top)
            .padding(.bottom, 32)
            
            items
            
            Spacer()
            
            blockButton
                .padding(.bottom)
        }
        .padding(.vertical, 24)
    }
    
    var items: some View {
        VStack(spacing: 32) {
            item(imageName: "calendar",
                 imageColor: .red,
                 title: "event_settings_onboarding_item_title_1".loc,
                 secondaryText: "event_settings_onboarding_item_desc_1".loc)
            item(imageName: "highlighter",
                 title: "event_settings_onboarding_item_title_2".loc,
                 secondaryText: "event_settings_onboarding_item_desc_2".loc)
            item(imageName: "info.circle",
                 imageColor: .green,
                 title: "event_settings_onboarding_item_title_3".loc,
                 secondaryText: "event_settings_onboarding_item_desc_3".loc)
        }
        .frame(maxWidth: isCollapsed ? 320 : 400)
    }
    
    func item(imageName: String,
              imageColor: Color = .accentColor,
              title: String,
              secondaryText: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: imageName)
                .frame(width: 50)
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .lineLimit(1)
                    .font(.body.weight(.medium))
                    .foregroundColor(.label)
                Text(secondaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension EventOnboardingView {
    var blockButton: some View {
        Button {
            action(true)
        } label: {
            Text(isEnabled ? "event_settings_onboarding_button_enabled".loc : "event_settings_onboarding_button".loc)
                .font(.body.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 300, height: 44)
                .background(Color.accentColor)
                .cornerRadius(10)
        }
    }
}

extension Color {
    static var label: Color {
        Color(UIColor.label)
    }
    
    static var secondaryLabel: Color {
        Color(UIColor.secondaryLabel)
    }
}
