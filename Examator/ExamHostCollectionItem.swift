//
//  ExamHostCollectionItem.swift
//  Examator
//
//  Created by Jan Hacker on 18/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//
/*  The “Collection View Item” is the controller that will mediate the flow 
    of information between the cells in your collection view and the model 
    objects (that is, the ExamHost object) that provide the data for your views. */

import Cocoa

class ExamHostCollectionItem: NSCollectionViewItem {

  //var selected : Bool = false // <- stored property of any NSCollectionViewItem
  @IBOutlet weak var hostArrayCtrl: NSArrayController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    NSLog("ExamHostCollectionItem:viewDidLoad()")
  }
  
  override func awakeFromNib() {
    NSLog("ExamHostCollectionItem:awakeFromNib() view: %@", view)
  }
  
  override func mouseDown(theEvent: NSEvent) {
    super.mouseDown(theEvent)
    if (theEvent.clickCount>1) {
      NSLog("doubleClick Event!")
    }
    // see comment section ...
    // http://www.springenwerk.com/2009/12/double-click-and-nscollectionview.html
  }

}