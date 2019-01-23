//
//  ListViewCell.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit

class ListViewCell: UITableViewCell {

    @IBOutlet weak var URLStringLabel: UILabel!
    
    var downloadClosure: ((ListViewCell) -> ())?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    @IBAction func download(_ sender: Any) {
        downloadClosure?(self)
    }
}
