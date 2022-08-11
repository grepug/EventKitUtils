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
    @State var tasks: [TaskValue] = []
    @State var checkedTaskIds: Set<String> = []
    
    public var body: some View {
        VStack {
            header
            content
            footer
        }
        .onAppear {
            Task {
                await reload()
            }
        }
        .onReceive(em.cachesReloaded) {
            Task {
                await reload()
            }
        }
    }
    
    var header: some View {
        HStack {
            Button {
                Task {
                    showingTodayTasks.toggle()
                    await reload()
                }
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
                pushToTaskListViewController()
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
                     isSummaryCard: true,
                     hidingKRInfo: true) {
            await checkTask(task)
        } presentEditor: {
            presentTaskEditor(task: task)
        }
        .padding(.top, 12)
        .background(Color(UIColor.systemBackground))
        .contextMenu {
            if em.testHasRepeatingTasks(with: task.repeatingInfo) {
                Button("查看重复任务") {
                    let vc = TaskListViewController(eventManager: em,
                                                    repeatingInfo: task.repeatingInfo)
                    parentVC.present(vc, animated: true)
                }
                
                Divider()
            }
            
            Button {
                presentTaskEditor(task: task)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            let label = Label("删除", systemImage: "trash")
            
            if #available(iOS 15.0, *) {
                Button(role: .destructive) {
                    removeTask(task)
                } label: {
                    label
                }
            } else {
                Button {
                    removeTask(task)
                } label: {
                    label
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
        .frame(height: 236)
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
        await reload()
    }
    
    func removeTask(_ task: TaskValue) {
        Task {
            await em.handleDeleteTask(task: task, on: parentVC) {
                tasks.removeAll { $0.normalizedID == task.normalizedID }
            }
            
            await reload()
        }
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
