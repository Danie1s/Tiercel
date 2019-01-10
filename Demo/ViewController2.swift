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

        downloadManager = (UIApplication.shared.delegate as! AppDelegate).downloadManager2
        


        URLStrings = ["http://api.gfs100.cn/upload/20171219/201712191530562229.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021621577474.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021048136875.mp4",
                      "http://api.gfs100.cn/upload/20180122/201801221619073224.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021048136875.mp4",
                      "http://api.gfs100.cn/upload/20180126/201801261120124536.mp4",
                      "http://api.gfs100.cn/upload/20180201/201802011423168057.mp4",
                      "http://api.gfs100.cn/upload/20180126/201801261545095005.mp4",
                      "http://api.gfs100.cn/upload/20171218/201712181643211975.mp4",
                      "http://api.gfs100.cn/upload/20171219/201712191351314533.mp4",
                      "http://api.gfs100.cn/upload/20180126/201801261644030991.mp4",
                      "http://api.gfs100.cn/upload/20180202/201802021322446621.mp4",
                      "http://api.gfs100.cn/upload/20180201/201802011038548146.mp4",
                      "http://api.gfs100.cn/upload/20180201/201802011545189269.mp4",
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
extension ViewController2 {


    @IBAction func addDownloadTask(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        let count = downloadURLStrings.count
        guard count < URLStrings.count else { return }

        guard let URLString = URLStrings.first(where: { !downloadURLStrings.contains($0) }) else { return }
        downloadURLStrings.append(URLString)
        let index = URLStrings.index(of: URLString)!
        downloadManager.download(URLString)
        tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        updateUI()
    }

    @IBAction func deleteDownloadTask(_ sender: Any) {
        guard let downloadManager = downloadManager else { return  }
        let count = downloadURLStrings.count
        guard count > 0 else { return }
        
        let index = count - 1
        let URLString = downloadURLStrings[index]
        downloadURLStrings.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        downloadManager.remove(URLString, completely: false)
        updateUI()
    }
}



