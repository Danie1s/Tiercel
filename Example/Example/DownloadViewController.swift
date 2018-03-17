//
//  DownloadViewController.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018年 Daniels. All rights reserved.
//

import UIKit

class DownloadViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalTasksLabel: UILabel!
    @IBOutlet weak var totalSpeedLabel: UILabel!
    @IBOutlet weak var timeRemainingLabel: UILabel!

    // 由于执行删除running的task，结果是异步回调的，所以最好是用downloadURLStrings作为数据源
    lazy var downloadURLStrings = [String]()

    let downloadManager = ListViewController.downloadManager


    override func viewDidLoad() {
        super.viewDidLoad()
        // tableView的设置
        automaticallyAdjustsScrollViewInsets = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.register(UINib(nibName: "DownloadTaskCell", bundle: nil), forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80


        // 检查磁盘空间
        let free = UIDevice.current.tr.freeDiskSpaceInBytes / 1024 / 1024
        print("手机剩余储存空间为： \(free)MB")


        // 因为会读取缓存到沙盒的任务，所以第一次的时候，不要马上开始下载
        downloadManager.isStartDownloadImmediately = false

        // 设置manager的回调
        downloadManager.progress { [weak self] (manager) in
            guard let strongSelf = self else { return }
            strongSelf.updateUI()
            }.success{ [weak self] (manager) in
                guard let strongSelf = self else { return }
                strongSelf.updateUI()
            }.failure { [weak self] (manager) in
                guard let strongSelf = self else { return }
                strongSelf.downloadURLStrings = strongSelf.downloadManager.tasks.map({ $0.URLString })
                strongSelf.tableView.reloadData()
                strongSelf.updateUI()
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        downloadURLStrings = downloadManager.tasks.map({ $0.URLString })
        updateUI()
        tableView.reloadData()
    }



    private func updateUI() {
        totalTasksLabel.text = "总任务：\(downloadManager.completedTasks.count)/\(downloadManager.tasks.count)"
        totalSpeedLabel.text = "总速度：\(downloadManager.speed.tr.convertSpeedToString())"
        timeRemainingLabel.text = "剩余时间： \(downloadManager.timeRemaining.tr.convertTimeToString())"
    }

}


// MARK: - tap event
extension DownloadViewController {

    @IBAction func totalStart(_ sender: Any) {
        downloadManager.isStartDownloadImmediately = true
        downloadManager.totalStart()
    }

    @IBAction func totalSuspend(_ sender: Any) {
        downloadManager.totalSuspend()
    }

    @IBAction func totalCancel(_ sender: Any) {
        downloadManager.totalCancel()
    }

    @IBAction func totalDelete(_ sender: Any) {
        downloadManager.totalRemove()
    }

    @IBAction func clearDisk(_ sender: Any) {
        downloadManager.cache.clearDiskCache()
        updateUI()
    }




    @IBAction func deleteDownloadTask(_ sender: Any) {
        let count = downloadManager.tasks.count
        let index = downloadManager.tasks.count - 1
        if count > 0 {
            let URLString = downloadURLStrings[index]
            downloadURLStrings.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            downloadManager.remove(URLString)
        }
        updateUI()
    }

    @IBAction func taskLimit(_ sender: Any) {
        downloadManager.maxConcurrentTasksLimit = 2
    }
    @IBAction func cancelTaskLimit(_ sender: Any) {
        downloadManager.maxConcurrentTasksLimit = 10000
    }

}


// MARK: - UITableViewDataSource & UITableViewDelegate
extension DownloadViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadURLStrings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! DownloadTaskCell

        let URLString = downloadURLStrings[indexPath.row]

        guard let task = downloadManager.fetchTask(URLString) else { return cell }

        var image: UIImage = #imageLiteral(resourceName: "resume")
        switch task.status {
        case .running:
            image = #imageLiteral(resourceName: "resume")
        case .suspend, .completed:
            image = #imageLiteral(resourceName: "suspend")
        default: break
        }
        cell.controlButton.setImage(image, for: .normal)

        cell.titleLabel.text = task.fileName

        cell.updateProgress(task: task)


        // task的闭包引用了cell，所以这里的task要用weak
        cell.tapClosure = { [weak self, weak task] cell in
            guard let task = task else { return }
            switch task.status {
            case .running:
                self?.downloadManager.suspend(URLString)
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            case .suspend:
                self?.downloadManager.start(URLString)
                cell.controlButton.setImage(#imageLiteral(resourceName: "resume"), for: .normal)
            default: break
            }
        }
        return cell
    }

    // 每个cell中的状态更新，应该在willDisplay中执行
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObjectAtIndex(indexPath.row),
            let task = downloadManager.fetchTask(URLString)
            else { return }

        task.progress { [weak cell] (task) in
            guard let cell = cell as? DownloadTaskCell else { return }
            cell.updateProgress(task: task)
        }
            .success({ [weak cell] (task) in
                print("下载完成")
                guard let cell = cell as? DownloadTaskCell else { return }
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            })
            .failure({ [weak cell] (task) in
                print("下载失败")
                guard let cell = cell as? DownloadTaskCell else { return }
                cell.controlButton.setImage(#imageLiteral(resourceName: "suspend"), for: .normal)
            })

    }

    // 由于cell是循环利用的，不在可视范围内的cell，不应该去更新cell的状态
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let URLString = downloadURLStrings.safeObjectAtIndex(indexPath.row),
            let task = downloadManager.fetchTask(URLString)
            else { return }

        task.progress { _ in }.success({ _ in }).failure({ _ in})
    }
}


