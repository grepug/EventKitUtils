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
                Text("日历同步")
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
                 title: "与系统日历联动".loc,
                 secondaryText: "在 Vision 创建的任务，自动同步创建到系统日历 app 的日程中".loc)
            item(imageName: "highlighter",
                 title: "任务重复、提醒".loc,
                 secondaryText: "开启日历同步后，支持创建重复任务、任务开始前的推送提醒。".loc)
            item(imageName: "arrow.counterclockwise",
                 imageColor: .green,
                 title: "读取日历日程".loc,
                 secondaryText: "Vision 会直接读取日历中通过 Vision 创建的日程，若需要任务在不同设备间同步，请开启日历 app 的 iCloud 同步".loc)
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
            Text(isEnabled ? "日历同步已开启，开始使用" : "开启日历同步")
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
