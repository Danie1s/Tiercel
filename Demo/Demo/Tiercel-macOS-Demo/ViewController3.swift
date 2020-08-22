//
//  ViewController3.swift
//  Tiercel-iOS-Demo
//
//  Created by 陈磊 on 2020/8/22.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class ViewController3: BaseViewController {
    
    
    override func viewDidLoad() {
        
        sessionManager = appDelegate.sessionManager3

        super.viewDidLoad()
        
        setupUI()

//        URLStrings = (NSArray(contentsOfFile: Bundle.main.path(forResource: "VideoURLStrings.plist", ofType: nil)!) as! [String])
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

        sessionManager.logger.option = .none

        updateUI()
        collectionView.reloadData()
        
    }

}


// MARK: - tap event
extension ViewController3 {


    @IBAction func multiDownload(_ sender: Any) {
        guard sessionManager.tasks.count < URLStrings.count else { return }
            
        // 如果同时开启的下载任务过多，会阻塞主线程，所以可以在子线程中开启
        DispatchQueue.global().async {
            self.sessionManager?.multiDownload(self.URLStrings) { [weak self] _ in
                self?.updateUI()
                self?.collectionView.reloadData()
            }
        }
    }
}
