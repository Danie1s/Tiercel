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
        
        sessionManager = appDelegate.sessionManager3

        super.viewDidLoad()

        URLStrings = (NSArray(contentsOfFile: Bundle.main.path(forResource: "VideoURLStrings.plist", ofType: nil)!) as! [String])
        
        setupManager()

        sessionManager.logger.option = .none

        updateUI()
        tableView.reloadData()
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
                self?.tableView.reloadData()
            }
        }
    }
}

