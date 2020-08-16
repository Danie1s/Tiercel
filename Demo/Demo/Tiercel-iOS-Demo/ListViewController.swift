//
//  ListViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ListViewController: UITableViewController {


    lazy var URLStrings: [String] = {
        return [
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
        ]
    }()



    override func viewDidLoad() {
        super.viewDidLoad()

    }


    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return URLStrings.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ListViewCell.reuseIdentifier, for: indexPath) as! ListViewCell
        cell.URLStringLabel.text = "文件\(indexPath.row + 1).mp4"
        let URLStirng = URLStrings[indexPath.row]
        cell.downloadClosure = { cell in
            appDelegate.sessionManager4.download(URLStirng, fileName: cell.URLStringLabel.text)
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }


}
