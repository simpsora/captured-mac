//
//  S3DetailViewController.swift
//  Captured
//
//  Created by Christopher Sexton on 12/9/15.
//  Copyright © 2015 Christopher Sexton. All rights reserved.
//

import Cocoa

class S3DetailViewController: AccountDetailViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
  }

  @IBOutlet weak var accessKeyField: NSTextField!
  @IBOutlet weak var secretKeyField: NSTextField!
  @IBOutlet weak var bucketNameField: NSTextField!
  @IBOutlet weak var publicURLField: NSTextField!
  @IBOutlet weak var nameLengthBox: NSComboBox!
  @IBOutlet weak var reducedRedundancyStorageButton: NSButton!

  
  @IBAction func testConnectionButton(sender: AnyObject) {
  }
  
}
