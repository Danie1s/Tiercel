//
//  DownloadViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit

class DownloadViewController: BaseViewController {


    override func viewDidLoad() {
        super.viewDidLoad()
        downloadManager = ListViewController.downloadManager

        // 因为会读取缓存到沙盒的任务，所以第一次的时候，不要马上开始下载
        downloadManager?.isStartDownloadImmediately = false

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

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let downloadManager = downloadManager else { return  }
        downloadURLStrings = downloadManager.tasks.map({ $0.URLString })
        updateUI()
        tableView.reloadData()
    }

}


// MARK: - tap event
extension DownloadViewController {

    @IBAction func deleteDownloadTask(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        let count = downloadManager.tasks.count
        let index = downloadManager.tasks.count - 1
        if count > 0 {
            let URLString = downloadURLStrings[index]
            downloadURLStrings.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            downloadManager.remove(URLString, completely: false)
        }
        updateUI()
    }

}


