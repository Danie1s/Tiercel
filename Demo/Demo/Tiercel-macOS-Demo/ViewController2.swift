//
//  ViewController2.swift
//  Tiercel-iOS-Demo
//
//  Created by 陈磊 on 2020/8/22.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class ViewController2: NSViewController {
    
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
        
        sessionManager = appDelegate.sessionManager2
        
        super.viewDidLoad()
        
        setupUI()
        
        URLStrings = [
            "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
            "http://issuecdn.baidupcs.com/issue/netdisk/MACguanjia/BaiduNetdisk_mac_2.2.3.dmg",
            "http://m4.pc6.com/cjh3/VicomsoftFTPClient.dmg",
            "https://qd.myapp.com/myapp/qqteam/pcqq/QQ9.0.8_2.exe",
            "http://gxiami.alicdn.com/xiami-desktop/update/XiamiMac-03051058.dmg",
            "http://113.113.73.41/r/baiducdnct-gd.inter.iqiyi.com/cdn/pcclient/20190413/13/25/iQIYIMedia_005.dmg?dis_dz=CT-GuangDong_GuangZhou&dis_st=36",
            "http://pcclient.download.youku.com/ikumac/youkumac_1.6.7.04093.dmg?spm=a2hpd.20022519.m_235549.5!2~5~5~5!2~P!3~A&file=youkumac_1.6.7.04093.dmg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg"
        ]
        
        
        setupManager()
        
        updateUI()
        self.collectionView.reloadData()
        
    }
    
    
    func setupUI() {
        // tableView的设置
        collectionView.register(ActivityCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActivityCollectionViewItem"))
        collectionView.dataSource = self
        collectionView.delegate = self
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

extension ViewController2: NSCollectionViewDataSource {
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

extension ViewController2: NSCollectionViewDelegate {
    
}

// MARK: - tap event
extension ViewController2 {
    
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

    @IBAction func addDownloadTask(_ sender: Any) {
        let downloadURLStrings = sessionManager.tasks.map { $0.url.absoluteString }
        guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
        
        sessionManager.download(URLString) { [weak self] _ in
            guard let self = self else { return }
            let index = self.sessionManager.tasks.count - 1
            self.collectionView.insertItems(at: [IndexPath(item: index, section: 0)])
            self.updateUI()
        }
    }

    @IBAction func deleteDownloadTask(_ sender: Any) {
        let count = sessionManager.tasks.count
        guard count > 0 else { return }
        let index = count - 1
        guard let task = sessionManager.tasks.safeObject(at: index) else { return }
        // tableView 刷新、 删除 task 都是异步的，如果操作过快会导致数据不一致，所以需要限制 button 的点击
        sessionManager.remove(task, completely: false) { [weak self] _ in
            self?.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            self?.updateUI()
        }
    }
    
    
    @IBAction func sort(_ sender: Any) {
        sessionManager.tasksSort { (task1, task2) -> Bool in
            if task1.startDate < task2.startDate {
                return task1.startDate < task2.startDate
            } else {
                return task2.startDate < task1.startDate
            }
        }
        self.collectionView.reloadData()
    }
}
