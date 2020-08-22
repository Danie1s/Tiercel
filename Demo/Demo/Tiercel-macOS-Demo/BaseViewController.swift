//
//  BaseViewController.swift
//  Tiercel-macOS-Demo
//
//  Created by 陈磊 on 2020/8/19.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class BaseViewController: NSViewController {

    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var totalTasksLabel: NSTextField!
    @IBOutlet weak var totalSpeedLabel: NSTextField!
    @IBOutlet weak var totalProgressLabel: NSTextField!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    
    @IBOutlet weak var taskLimitSwitch: NSSwitch!
    
    var sessionManager: SessionManager!

    var URLStrings: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        sessionManager.logger.option = .default
        
        updateSwicth()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        let layout = collectionView.collectionViewLayout as! NSCollectionViewFlowLayout
        layout.itemSize = NSSize(width: NSApplication.shared.mainWindow!.frame.width - 40, height: 120)
    }
    
    
    func setupUI() {
        
        // collectionView 的设置
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ActivityCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActivityCollectionViewItem"))
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

extension BaseViewController {
    @IBAction func totalStart(_ sender: Any) {
        sessionManager.totalStart { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    @IBAction func totalSuspend(_ sender: Any) {
        sessionManager.totalSuspend() { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    @IBAction func totalCancel(_ sender: Any) {
        sessionManager.totalCancel() { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    @IBAction func totalDelete(_ sender: Any) {
        sessionManager.totalRemove(completely: false) { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    @IBAction func clearDisk(_ sender: Any) {
        sessionManager.cache.clearDiskCache()
        updateUI()
    }
    
    @IBAction func taskLimit(_ sender: NSSwitch) {
        if sender.isOn {
            sessionManager.configuration.maxConcurrentTasksLimit = 2
        } else {
            sessionManager.configuration.maxConcurrentTasksLimit = Int.max
        }
    }
}

extension BaseViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return sessionManager.tasks.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActivityCollectionViewItem"), for: indexPath) as! ActivityCollectionViewItem
        return item
    }
}

extension BaseViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        guard let task = sessionManager.tasks.safeObject(at: indexPath.item),
            let item = item as? ActivityCollectionViewItem else { return }
        item.titleLabel.stringValue = task.fileName
        
        item.updateProgress(task)
        item.tapClosure = { [weak self] cell in
            // 由于 cell 是循环利用的，所以要在闭包里面获取正确的 indexPath，从而得到正确的 task
            guard let indexPath = self?.collectionView.indexPath(for: item),
                let task = self?.sessionManager.tasks.safeObject(at: indexPath.item)
                else { return }
            switch task.status {
            case .waiting, .running:
                self?.sessionManager.suspend(task)
            case .suspended, .failed:
                self?.sessionManager.start(task)
            default: break
            }
        }

        task.progress { [weak item] (task) in
                item?.updateProgress(task)
            }
            .success { [weak item] (task) in
                item?.updateProgress(task)
                // 下载任务成功了

            }
            .failure { [weak item] (task) in
                item?.updateProgress(task)
                if task.status == .suspended {
                    // 下载任务暂停了
                }

                if task.status == .failed {
                    // 下载任务失败了
                }
                if task.status == .canceled {
                    // 下载任务取消了
                }
                if task.status == .removed {
                    // 下载任务移除了
                }
            }
    }
    
    func collectionView(_ collectionView: NSCollectionView, didEndDisplaying item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        guard let task = sessionManager.tasks.safeObject(at: indexPath.item) else { return }
        task.progress { _ in }.success { _ in } .failure { _ in }
    }
}


extension NSSwitch {
    var isOn: Bool {
        set {
            if newValue {
                self.state = .on
            } else {
                self.state = .off
            }
        }
        get { self.state == .on }
    }
}
