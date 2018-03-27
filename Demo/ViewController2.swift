//
//  ViewController2.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ViewController2: BaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        downloadManager = TRManager("ViewController2", isStoreInfo: true)
        
        // 因为会读取缓存到沙盒的任务，所以第一次的时候，不要马上开始下载
        downloadManager?.isStartDownloadImmediately = false

        URLStrings = (1...9).map({ "http://120.25.226.186:32812/resources/videos/minion_0\($0).mp4" })

        guard let downloadManager = downloadManager else { return  }

        // 设置manager的回调
        downloadManager.progress { [weak self] (manager) in
            guard let strongSelf = self else { return }
            strongSelf.updateUI()
        }.success{ [weak self] (manager) in
            guard let strongSelf = self else { return }
            strongSelf.updateUI()
        }.failure { [weak self] (manager) in
            guard let strongSelf = self,
            let downloadManager = strongSelf.downloadManager
            else { return }
            strongSelf.downloadURLStrings = downloadManager.tasks.map({ $0.URLString })
            strongSelf.tableView.reloadData()
            strongSelf.updateUI()
        }
        
        let tasks = downloadManager.tasks
        tasks.forEach { downloadURLStrings.append($0.URLString)}
        updateUI()
        tableView.reloadData()

    }

    deinit {
        downloadManager?.invalidate()
    }

}


// MARK: - tap event
extension ViewController2 {


    @IBAction func addDownloadTask(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        downloadManager.isStartDownloadImmediately = true
        let index = downloadURLStrings.count
        if index < 9 {
            guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
            downloadURLStrings.append(URLString)
            let index = URLStrings.index(of: URLString)!
            downloadManager.download(URLString, fileName: "小黄人\(index + 1).mp4")
            tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
        updateUI()
    }

    @IBAction func deleteDownloadTask(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        let count = downloadURLStrings.count
        let index = count - 1
        if count > 0 {
            let URLString = downloadURLStrings[index]
            downloadURLStrings.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            downloadManager.remove(URLString, completely: false)
        }
        updateUI()
    }
}



