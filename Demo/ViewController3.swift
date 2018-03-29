//
//  ViewController3.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController3: BaseViewController {


    override func viewDidLoad() {
        super.viewDidLoad()

        downloadManager = TRManager("ViewController3", isStoreInfo: true)
        
        // 因为会读取缓存到沙盒的任务，所以第一次的时候，不要马上开始下载
        downloadManager?.isStartDownloadImmediately = false

        URLStrings = (1...5).map({ "http://120.25.226.186:32812/resources/videos/minion_0\($0).mp4" })
        
        guard let downloadManager = downloadManager else { return  }

        setupManager()

        downloadURLStrings = downloadManager.tasks.map({ $0.URLString })

        updateUI()
        tableView.reloadData()
    }


    deinit {
        downloadManager?.invalidate()
    }

}


// MARK: - tap event
extension ViewController3 {


    @IBAction func multiDownload(_ sender: Any) {
        downloadManager?.isStartDownloadImmediately = true
        downloadManager?.multiDownload(URLStrings)
        downloadURLStrings.append(contentsOf: URLStrings)
        updateUI()
        tableView.reloadData()
    }

}

