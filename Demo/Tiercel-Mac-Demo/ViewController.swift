//
//  ViewController.swift
//  Tiercel-Mac-Demo
//
//  Created by 刘小龙 on 2025/8/12.
//  Copyright © 2025 Daniels. All rights reserved.
//

import Cocoa
import Tiercel


class ViewController: NSViewController {
    
    @IBOutlet weak var totalTasksLabel: NSTextField!
    @IBOutlet weak var totalSpeedLabel: NSTextField!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var totalProgressLabel: NSTextField!
    
    var sessionManager: SessionManager!
    
    var URLStrings: [String] = []

    override func viewDidLoad() {
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
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg",
            "https://r1---sn-ni5eln7e.gvt1-cn.com/edgedl/android/studio/install/2025.1.1.13/android-studio-2025.1.1.13-mac_arm.dmg",
            "https://dldir.y.qq.com/ecosfile/music_clntupate/mac/other/QQMusicMac10.7.0Build01.dmg"
        ]
        
        
        var configuration = SessionConfiguration()
        configuration.allowsCellularAccess = true
        let path = Cache.defaultDiskCachePathClosure("Test")
        let cacahe = Cache("ViewController2", downloadPath: path)
        
        let manager = SessionManager("ViewController2", configuration: configuration, cache: cacahe, operationQueue: DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue"))
        sessionManager = manager
        
        
        sessionManager.configuration.maxConcurrentTasksLimit = 3
        
        setupManager()
        updateUI()
    }

   
    func setupUI() {
        
    }
    
    
    func setupManager() {
        
        // 设置 manager 的回调
        sessionManager.progress { [weak self] (manager) in
            self?.updateUI()
            
        }.completion { [weak self] manager in
            self?.updateUI()
            if manager.status == .succeeded {
                // 下载成功
            } else {
                // 其他状态
            }
        }
    }
    
    func updateUI() {
        totalTasksLabel.stringValue = "\(sessionManager.succeededTasks.count)/\(sessionManager.tasks.count)"
        totalSpeedLabel.stringValue = "\(sessionManager.speedString)"
        timeRemainingLabel.stringValue = "剩余时间： \(sessionManager.timeRemainingString)"
        let per = String(format: "%.2f", sessionManager.progress.fractionCompleted)
        totalProgressLabel.stringValue = "\(per)"
    }
    
    
    
    @IBAction func downAllAction(_ sender: Any) {
        
        
        self.sessionManager?.multiDownload(self.URLStrings) { [weak self] _ in
            self?.updateUI()
            
        
        }
        
        
    }
    
    
    
    @IBAction func totalStart(_ sender: Any) {
        sessionManager.totalStart { [weak self] _ in
             
        }
    }
    
    @IBAction func totalSuspend(_ sender: Any) {
        sessionManager.totalSuspend() { [weak self] _ in
            
            
        }
    }
    
    @IBAction func totalCancel(_ sender: Any) {
        sessionManager.totalCancel() { [weak self] _ in
            
        }
    }
    
    @IBAction func totalDelete(_ sender: Any) {
        sessionManager.totalRemove(completely: false) { [weak self] _ in
            
        }
    }
    
    @IBAction func clearDisk(_ sender: Any) {
        sessionManager.cache.clearDiskCache()
        updateUI()
    }
    
    
}

