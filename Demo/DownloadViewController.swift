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

        downloadManager = appDelegate.downloadManager4

        setupManager()

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
        guard count > 0 else { return }

        let index = count - 1
        let URLString = downloadURLStrings[index]
        downloadURLStrings.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        downloadManager.remove(URLString, completely: false)
        updateUI()
    }

}


