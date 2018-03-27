//
//  ListViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit
import Tiercel

class ListViewController: UITableViewController {

    static let downloadManager = TRManager("ListViewController", isStoreInfo: true)

    lazy var URLStrings: [String] = {
        return (1...9).map({ "http://120.25.226.186:32812/resources/videos/minion_0\($0).mp4" })
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }


    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return URLStrings.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath) as! ListViewCell
        cell.URLStringLabel.text = "小黄人\(indexPath.row + 1).mp4"
        let URLStirng = URLStrings[indexPath.row]
        cell.downloadClosure = { cell in
            ListViewController.downloadManager.isStartDownloadImmediately = true
            ListViewController.downloadManager.download(URLStirng, fileName: cell.URLStringLabel.text)
        }

        return cell
    }


}
