//
//  DownloadTaskCell.swift
//  Tiercel-Mac-Demo
//
//  Created by 刘小龙 on 2025/8/30.
//  Copyright © 2025 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class DownloadTaskCell: NSCollectionViewItem {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var speedLabel: NSTextField!
    @IBOutlet weak var bytesLabel: NSTextField!
    @IBOutlet weak var controlButton: NSButton!
    @IBOutlet weak var progressView: NSProgressIndicator!
    @IBOutlet weak var timeRemainingLabel: NSTextField!
    @IBOutlet weak var startDateLabel: NSTextField!
    @IBOutlet weak var endDateLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!

    
    var tapClosure: ((DownloadTaskCell) -> Void)?
    var removeClosure: ((DownloadTaskCell) -> Void)?
    var task: DownloadTask?

    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.lightGray.cgColor
    }
    
    
    @IBAction func didTapButton(_ sender: Any) {
        tapClosure?(self)
    }
    
    @IBAction func removeAction(_ sender: Any) {
        removeClosure?(self)
    }
    

    func updateProgress(_ task: DownloadTask) {
        progressView.observedProgress = task.progress
        bytesLabel.stringValue = "\(task.progress.completedUnitCount.tr.convertBytesToString())/\(task.progress.totalUnitCount.tr.convertBytesToString())"
        speedLabel.stringValue = task.speedString
        timeRemainingLabel.stringValue = "剩余时间：\(task.timeRemainingString)"
        startDateLabel.stringValue = "开始时间：\(task.startDateString)"
        endDateLabel.stringValue = "结束时间：\(task.endDateString)"
        
        var image = NSImage(systemSymbolName: "pause", accessibilityDescription: "")
        switch task.status {
        case .suspended:
            statusLabel.stringValue = "暂停"
            statusLabel.textColor = .black
            image = NSImage(systemSymbolName: "play", accessibilityDescription: "")
            
        case .running:
            image = NSImage(systemSymbolName: "pause", accessibilityDescription: "")
            statusLabel.stringValue = "下载中"
            statusLabel.textColor = .blue
        case .succeeded:
            statusLabel.stringValue = "成功"
            statusLabel.textColor = .green
        case .failed:
            statusLabel.stringValue = "失败"
            statusLabel.textColor = .red
        case .waiting:
            statusLabel.stringValue = "等待中"
            statusLabel.textColor = .orange
        default:
            break
        }
        controlButton.image = image
    }
    
}
