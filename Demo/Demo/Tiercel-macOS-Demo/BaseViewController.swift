//
//  BaseViewController.swift
//  Tiercel-macOS-Demo
//
//  Created by 陈磊 on 2020/8/19.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

extension NSSwitch {
    var isOn: Bool {
        set {
            if newValue {
                self.state = .on
            } else {
                self.state = .off
            }
        }
        get {
            return self.state == .on
        }
    }
}

class BaseViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var totalTasksLabel: NSTextField!
    @IBOutlet weak var totalSpeedLabel: NSTextField!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var totalProgressLabel: NSTextField!
    
    @IBOutlet weak var taskLimitSwitch: NSSwitch!
    @IBOutlet weak var cellularAccessSwitch: NSSwitch!
    
    var sessionManager: SessionManager!

    var URLStrings: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func setupUI() {
        // tableView的设置
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NSNib(nibNamed: "ActivityCollectionViewItem", bundle: nil), forItemWithIdentifier: .init("ActivityCollectionViewItem"))
        configureNavigationItem()
    }
    
    func configureNavigationItem() {
//        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "编辑",
//                                          style: .plain,
//                                          target: self,
//                                          action: #selector(toggleEditing))
    }
    
    
    @objc func toggleEditing() {
//        tableView.setEditing(!tableView.isEditing, animated: true)
//        let button = navigationItem.rightBarButtonItem!
//        button.title = tableView.isEditing ? "完成" : "编辑"
    }

    func updateUI() {
        totalTasksLabel.stringValue = "总任务：\(sessionManager.succeededTasks.count)/\(sessionManager.tasks.count)"
        totalSpeedLabel.stringValue = "总速度：\(sessionManager.speedString)"
        timeRemainingLabel.stringValue = "剩余时间： \(sessionManager.timeRemainingString)"
        let per = String(format: "%.2f", sessionManager.progress.fractionCompleted)
        totalProgressLabel.stringValue = "总进度： \(per)"
    }
    
    func updateSwicth() {
        taskLimitSwitch.isOn = sessionManager.configuration.maxConcurrentTasksLimit < 3
        cellularAccessSwitch.isOn = sessionManager.configuration.allowsCellularAccess
    }

    func setupManager() {

        // 设置 manager 的回调
        sessionManager.progress { [weak self] (manager) in
            self?.updateUI()
            
        }.completion { [weak self] (task) in
            self?.updateUI()
            if task.status == .succeeded {
                // 下载成功
            } else {
                // 其他状态
            }
        }
    }
}

extension BaseViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return sessionManager.tasks.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActivityCollectionViewItem"), for: indexPath)
        if let c = cell as? ActivityCollectionViewItem {
            let task = sessionManager.tasks[indexPath.item]
            c.update(with: task)
        }
        return cell
    }
}

extension BaseViewController: NSCollectionViewDelegate {
    
}
