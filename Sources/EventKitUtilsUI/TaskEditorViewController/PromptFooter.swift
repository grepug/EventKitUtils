//
//  PromptFooter.swift
//  
//
//  Created by Kai Shao on 2022/10/4.
//

import SwiftUI

struct PromptFooter: View {
    var text: String
    var isError: Bool = false
    
    var body: some View {
        Group {
            if !isError {
                Text(text)
            } else {
                Label {
                    Text(text)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .foregroundColor(.secondary)
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing)
        .padding([.top, .bottom], 8)
    }
}
