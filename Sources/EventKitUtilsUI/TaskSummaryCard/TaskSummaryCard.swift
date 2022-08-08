//
//  TaskSummaryCard.swift
//  
//
//  Created by Kai on 2022/8/4.
//

import SwiftUI
import EventKitUtils

public struct TaskSummaryCard: View {
    public init(eventManager: EventManager, parentVC: UIViewController, showMore: @escaping () -> Void) {
        self.em = eventManager
        self.parentVC = parentVC
        self.showMore = showMore
    }
    
    let em: EventManager
    let parentVC: UIViewController
    var showMore: () -> Void
    
    @AppStorage("showingTodayTasks") var showingTodayTasks = true
    @State var tasks: [TaskValue] = []
    @State var checkedTaskIds: Set<String> = []
    
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
    }
    
    func taskItem(_ task: TaskValue) -> some View {
        TaskListCell(task: task,
                     checked: checkedTaskIds.contains(task.normalizedID),
                     isSummaryCard: true) {
            await checkTask(task)
        } presentEditor: {
            presentTaskEditor(task: task)
        }
        .padding(.top, 12)
        .background(Color(UIColor.systemBackground))
        .contextMenu {
            if #available(iOS 15.0, *) {
                if em.testHasRepeatingTasks(with: task) {
                    Button("查看重复任务") {
                        let vc = TaskListViewController(eventManager: em, fetchingTitle: task.normalizedTitle)
                        parentVC.present(vc, animated: true)
                    }
                    
                    Divider()
                }
                
                Button {
                    presentTaskEditor(task: task)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                    
                Button(role: .destructive) {
                    Task {
                        await em.handleDeleteTask(task: task, on: parentVC) {
                            tasks.removeAll { $0.normalizedID == task.normalizedID }
                        }
                        
                        reload()
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
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
    func checkTask(_ task: TaskValue) async {
        checkedTaskIds.insert(task.normalizedID)

        try! await Task.sleep(nanoseconds: 300_000_000)
        
        for taskID in checkedTaskIds {
            let task = tasks.first(where: { $0.normalizedID == taskID })!
            await em.toggleCompletion(task)
        }
        
        checkedTaskIds.removeAll()
        
        reload()
    }
    
    func relativeDateColor(_ task: TaskKind) -> Color {
        let days = task.normalizedEndDate.map { Date().days(to: $0, includingLastDay: false) } ?? 1
            
        if days == 0 {
            return .green
        } else if days < 0 {
            return .red
        }
        
        return .secondary
    }
}
