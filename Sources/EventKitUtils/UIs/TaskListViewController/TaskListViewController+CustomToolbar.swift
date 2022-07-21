//
//  File.swift
//  
//
//  Created by Kai on 2022/7/21.
//

import UIKit

extension TaskListViewController {
    private func makeCustomToolbar() -> UIView {
        let containerView = UIView()
        let stackView = UIView()
        
        stackView.addSubview(segmentControl)
        stackView.addSubview(addButton)

        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.width.equalTo(32)
            make.verticalEdges.equalToSuperview()
        }
        
        addButton.sizeToFit()
        
        segmentControl.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalTo(addButton.snp.leading).offset(-12)
            make.verticalEdges.equalToSuperview()
        }
        
        containerView.addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        
        containerView.backgroundColor = UIColor {
            $0.userInterfaceStyle == .dark ? .systemGroupedBackground : .systemBackground
        }
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.gray.cgColor
        containerView.layer.shadowOffset = .init(width: 1.5, height: 1.5)
        containerView.layer.shadowRadius = 5
        containerView.layer.shadowOpacity = 0.5
        
        return containerView
    }
    
    func setupCustomToolbar() {
        let toolbar = makeCustomToolbar()
        view.addSubview(toolbar)
        
        toolbar.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }
    }
}

