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
        super.viewDidLoad()

        sessionManager = appDelegate.sessionManager2


        URLStrings = ["https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Office_16.24.19041401_Installer.pkg",
                      "http://m6.pc6.com/xuh6/navicatpre12115.zip",
                      "http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",
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
                      "http://api.gfs100.cn/upload/20171219/201712190944143459.mp4"]
        
        guard let downloadManager = sessionManager else { return  }

        setupManager()

        downloadURLStrings = downloadManager.tasks.map({ $0.url.absoluteString })

        updateUI()
        tableView.reloadData()
        
    }
}


// MARK: - tap event
extension ViewController2 {

    @IBAction func addDownloadTask(_ sender: Any) {
        guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
        downloadURLStrings.append(URLString)
        sessionManager?.download(URLString)
        let index = downloadURLStrings.count - 1
        tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        updateUI()
    }

    @IBAction func deleteDownloadTask(_ sender: Any) {
        let count = downloadURLStrings.count
        guard count > 0 else { return }
        
        let index = count - 1
        let URLString = downloadURLStrings[index]
        downloadURLStrings.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        sessionManager?.remove(URLString, completely: false,  { [weak self] _ in
            self?.updateUI()
        })

        
    }
}



