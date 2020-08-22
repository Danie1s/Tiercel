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
        presentAsModalWindow(viewController1)
    }
    
    @IBAction func buttonAction2(_ sender: Any) {
        let viewcontroller2 = ViewController2()
        presentAsModalWindow(viewcontroller2)
    }
    
    @IBAction func buttonAction3(_ sender: Any) {
    }
    
    @IBAction func buttonAction4(_ sender: Any) {
    }
}

