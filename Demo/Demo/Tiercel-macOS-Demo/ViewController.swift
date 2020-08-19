//
//  ViewController.swift
//  Tiercel-macOS-Demo
//
//  Created by Daniels on 2020/8/17.
//  Copyright © 2020 Daniels. All rights reserved.
//

import Cocoa
import Tiercel

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func buttonAction1(_ sender: Any) {
        let viewController1 = ViewController1()
        presentAsSheet(viewController1)
    }
    
}

