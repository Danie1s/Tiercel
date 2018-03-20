//
//  ViewController3.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit

class ViewController3: BaseViewController {


    override func viewDidLoad() {
        super.viewDidLoad()

        downloadManager = TRManager("ViewController3", isStoreInfo: true)

        URLStrings = (1...5).map({ "http://120.25.226.186:32812/resources/videos/minion_0\($0).mp4" })
        
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

