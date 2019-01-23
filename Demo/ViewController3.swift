//
//  ViewController3.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController3: BaseViewController {


    override func viewDidLoad() {
        super.viewDidLoad()

        downloadManager = appDelegate.downloadManager3

        URLStrings = ["http://api.gfs100.cn/upload/20171219/201712191530562229.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021621577474.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021048136875.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021436174669.mp4",
                      "http://api.gfs100.cn/upload/20180131/201801311435101664.mp4",
                      "http://api.gfs100.cn/upload/20180131/201801311059389211.mp4",
                      "http://api.gfs100.cn/upload/20171219/201712190944143459.mp4"]
        
        guard let downloadManager = downloadManager else { return  }

        setupManager()

        downloadURLStrings = downloadManager.tasks.map({ $0.URLString })

        updateUI()
        tableView.reloadData()
    }
}


// MARK: - tap event
extension ViewController3 {


    @IBAction func multiDownload(_ sender: Any) {
        if downloadURLStrings.isEmpty {
            downloadURLStrings.append(contentsOf: URLStrings)
            downloadManager?.multiDownload(URLStrings)
            updateUI()
            tableView.reloadData()
        }
    }

}

