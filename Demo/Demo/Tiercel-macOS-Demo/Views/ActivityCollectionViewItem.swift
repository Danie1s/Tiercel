//
//  ActivityCollectionViewItem.swift
//  Octofile
//
//  Created by 陈磊 on 2020/6/7.
//  Copyright © 2020 Hypobenthos. All rights reserved.
//

import Cocoa
import CoreServices
import Tiercel

class ActivityCollectionViewItem: NSCollectionViewItem {

    @IBOutlet weak var logoImageView: NSImageView!
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var sizeLabel: NSTextField!
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var progressView: NSProgressIndicator!
    
    private var observation: NSKeyValueObservation?
    private var fetchProgress: Progress? {
        didSet {
            observation?.invalidate()
            guard let progress = fetchProgress else {
                return
            }
            observation = progress.observe(\.fractionCompleted, options: [.initial, .new], changeHandler: { [weak self] (progress, changed) in
                DispatchQueue.main.async {
                    self?.updateWithProgress(progress: progress)
                }
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func update(with task: DownloadTask?) {
        nameLabel.stringValue = task?.fileName ?? ""
        fetchProgress = task?.progress
        
        if let pathExtension = task?.url.pathExtension, let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() {
            let icon = NSWorkspace.shared.icon(forFileType: UTI as String)
            logoImageView.image = icon
        } else {
            logoImageView.image = nil
        }
    }
    
    func updateWithProgress(progress: Progress?) {
        if let progress = progress {
            let currentProgress = progress.fractionCompleted * 100
            progressLabel.stringValue = "\(Int(currentProgress))%"
            progressView.doubleValue = currentProgress
            sizeLabel.stringValue = "\(progress.fractionCompleted)"
            progressView.isHidden = progress.isFinished
        } else {
            progressLabel.stringValue = "0%"
            progressView.doubleValue = 0.0
            sizeLabel.stringValue = ""
        }
    }
}
