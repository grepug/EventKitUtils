//
//  TaskSummaryCard.swift
//  
//
//  Created by Kai on 2022/8/4.
//

import SwiftUI
import EventKitUtils

public struct TaskSummaryCard: View {
    public init(vm: TaskSummaryCardViewModel) {
        self.vm = vm
    }
    
    @ObservedObject var vm: TaskSummaryCardViewModel
    
    public var body: some View {
        VStack {
            header
            content
            footer
        }
        .onAppear {
            vm.reloadSubject.send()
        }
    }
    
    var header: some View {
        HStack {
            Button {
                Task {
                    vm.showingTodayTasks.toggle()
                    vm.reloadSubject.send()
                }
            } label: {
                HStack {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.square")
                        Text(vm.showingTodayTasks ? "v3_task_today_tasks".loc : "v3_task_recent_tasks".loc)
                    }
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.footnote)
                }
                .font(.subheadline.bold())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                vm.pushToTaskListViewController()
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
                vm.presentTaskEditor()
            } label: {
                Label("v3_task_create_task".loc, systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
        .padding([.trailing, .bottom])
    }
    
    var list: some View {
        VStack {
            ForEach(vm.tasks, id: \.normalizedID) { task in
                taskItem(task)
            }
            
            Spacer()
        }
        .animation(.default)
    }
    
    func taskItem(_ task: TaskValue) -> some View {
        TaskListCell(task: task,
                     isSummaryCard: true,
                     checked: vm.checkedTaskIds.contains(task.normalizedID),
                     hidingKRInfo: true) {
            await vm.checkTask(task)
        } presentEditor: {
            vm.presentTaskEditor(task: task)
        }
        .padding(.top, 12)
        .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground }))
        .contextMenu {
            if vm.em.testHasRepeatingTasks(with: task.repeatingInfo) {
                Button("view_repeat_tasks".loc) {
                    vm.presentRepeatTasks(for: task)
                }
                
                Divider()
            }
            
            Button {
                vm.presentTaskEditor(task: task)
            } label: {
                Label("action_edit".loc, systemImage: "pencil")
            }
            
            let label = Label("action_discard".loc, systemImage: "trash")
            
            if #available(iOS 15.0, *) {
                Button(role: .destructive) {
                    vm.removeTask(task)
                } label: {
                    label
                }
            } else {
                Button {
                    vm.removeTask(task)
                } label: {
                    label
                }
            }
        }
    }
    
    var content: some View {
        Group {
            if vm.tasks.isEmpty {
                Text(vm.showingTodayTasks ?
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
