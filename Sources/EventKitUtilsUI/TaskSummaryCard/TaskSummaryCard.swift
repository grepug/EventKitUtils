//
//  TaskSummaryCard.swift
//  
//
//  Created by Kai on 2022/8/4.
//

import SwiftUI
import EventKitUtils

public struct TaskSummaryCard: View {
    public init(eventManager: EventManager, parentVC: UIViewController) {
        self.em = eventManager
        self.parentVC = parentVC
    }
    
    let em: EventManager
    let parentVC: UIViewController
    
    @AppStorage("showingTodayTasks") var showingTodayTasks = true
    @State var tasks: [TaskKind] = []
    @State var checkedDict: [String: Bool] = [:]
    
    public var body: some View {
        VStack {
            header
            content
            footer
        }
        .onAppear {
            reload()
        }
    }
    
    var header: some View {
        HStack {
            Button {
                showingTodayTasks.toggle()
                reload()
            } label: {
                HStack {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.square")
                        Text(showingTodayTasks ? "v3_task_today_tasks".loc : "v3_task_recent_tasks".loc)
                    }
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.footnote)
                }
                .font(.subheadline.bold())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                showMore()
            } label: {
                Text("\("v3_task_view_more".loc) >")
                    .font(.caption)
            }
        }
        .foregroundColor(.accentColor)
        .padding([.horizontal, .top])
    }
    
    var footer: some View {
        HStack {
            Spacer()
            
            Button {
                presentTaskEditor()
            } label: {
                Label("v3_task_create_task".loc, systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
        .padding([.trailing, .bottom])
    }
    
    var list: some View {
        VStack {
            ForEach(tasks, id: \.normalizedID) { task in
                taskItem(task)
            }
            
            Spacer()
        }
        .animation(.default)
        .padding(.horizontal)
    }
    
    func taskItem(_ task: TaskKind) -> some View {
        TaskListCell(task: task, isSummaryCard: true) {
            checkedDict[task.normalizedID] = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                task.toggleCompletion()
                checkedDict.removeAll()
            }
        } presentEditor: {
            presentTaskEditor(task: task)
        }
        .padding(.top, 12)
    }
    
    var content: some View {
        Group {
            if tasks.isEmpty {
                Text(showingTodayTasks ?
                     "v3_task_today_no_tasks".loc :
                        "v3_task_no_tasks".loc)
                .foregroundColor(.secondary)
            } else {
                list
            }
        }
        .frame(height: 216)
    }
}

extension TaskSummaryCard {
    func relativeDateColor(_ task: TaskKind) -> Color {
        let days = task.normalizedEndDate.map { Date().days(to: $0, includingLastDay: false) } ?? 1
            
        if days == 0 {
            return .green
        } else if days < 0 {
            return .red
        }
        
        return .secondary
    }
    
    func isTaskChecked(_ task: TaskKind) -> Bool {
        checkedDict[task.normalizedID] == true
    }
}
