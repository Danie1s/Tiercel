//
//  ViewController2.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController2: BaseViewController {

    override func viewDidLoad() {
        
        sessionManager = appDelegate.sessionManager2

        super.viewDidLoad()


        URLStrings = [
            "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
            "http://issuecdn.baidupcs.com/issue/netdisk/MACguanjia/BaiduNetdisk_mac_2.2.3.dmg",
            "http://m4.pc6.com/cjh3/VicomsoftFTPClient.dmg",
            "https://qd.myapp.com/myapp/qqteam/pcqq/QQ9.0.8_2.exe",
            "http://gxiami.alicdn.com/xiami-desktop/update/XiamiMac-03051058.dmg",
            "http://113.113.73.41/r/baiducdnct-gd.inter.iqiyi.com/cdn/pcclient/20190413/13/25/iQIYIMedia_005.dmg?dis_dz=CT-GuangDong_GuangZhou&dis_st=36",
            "http://pcclient.download.youku.com/ikumac/youkumac_1.6.7.04093.dmg?spm=a2hpd.20022519.m_235549.5!2~5~5~5!2~P!3~A&file=youkumac_1.6.7.04093.dmg",
            "http://api.gfs100.cn/upload/20180126/201801261545095005.mp4",
            "http://dldir1.qq.com/qqfile/QQforMac/QQ_V4.2.4.dmg",
            "http://api.gfs100.cn/upload/20171218/201712181643211975.mp4",
            "http://api.gfs100.cn/upload/20171219/201712191351314533.mp4",
            "http://api.gfs100.cn/upload/20180126/201801261644030991.mp4",
            "http://api.gfs100.cn/upload/20180202/201802021322446621.mp4",
            "http://api.gfs100.cn/upload/20180201/201802011038548146.mp4",
            "http://api.gfs100.cn/upload/20180201/201802011545189269.mp4",
            "http://api.gfs100.cn/upload/20180202/201802021436174669.mp4",
            "http://api.gfs100.cn/upload/20180202/201802021048136875.mp4",
            "http://api.gfs100.cn/upload/20180122/201801221619073224.mp4",
            "http://api.gfs100.cn/upload/20180202/201802021048136875.mp4",
            "http://api.gfs100.cn/upload/20180126/201801261120124536.mp4",
            "http://api.gfs100.cn/upload/20180201/201802011423168057.mp4",
            "http://api.gfs100.cn/upload/20180131/201801311435101664.mp4",
            "http://api.gfs100.cn/upload/20180131/201801311059389211.mp4",
            "http://api.gfs100.cn/upload/20171219/201712190944143459.mp4"
        ]
        

        setupManager()

        updateUI()
        tableView.reloadData()
        
    }
}


// MARK: - tap event
extension ViewController2 {

    @IBAction func addDownloadTask(_ sender: Any) {
        let downloadURLStrings = sessionManager.tasks.map { $0.url.absoluteString }
        guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
        if let _ = sessionManager.download(URLString) {
            let index = sessionManager.tasks.count - 1
            tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            updateUI()
        }
    }

    @IBAction func deleteDownloadTask(_ sender: UIButton) {
        let count = sessionManager.tasks.count
        guard count > 0 else { return }
        let index = count - 1
        guard let task = sessionManager.tasks.safeObject(at: index) else { return }
        // tableView 刷新和删除task都是异步的，如果操作过快会导致数据不一致，所以需要限制button的点击
        sender.isEnabled = false
        sessionManager.remove(task, completely: false) { [weak self] _ in
            self?.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            self?.updateUI()
            sender.isEnabled = true
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
        tableView.reloadData()
    }
}



