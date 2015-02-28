//
//  SetupViewController.swift
//  Examator
//
//  Created by jan on 17/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//

import Cocoa

class SetupViewController: NSViewController {
  // ExamViewController's window
  @IBOutlet weak var mainWindow: NSWindow!
  @IBOutlet weak var hostArrayCtrl: NSArrayController!
  // Our input form fields
  @IBOutlet weak var exercisesPathTextbox: NSTextField!
  @IBOutlet weak var resultsPathTextbox: NSTextField!
  @IBOutlet var sshIdentityTextbox: NSTextField!
  @IBOutlet var sshUsernameTextbox: NSTextField!
  @IBOutlet var myTableView: NSTableView!
  
  dynamic var plannedStart: NSDate = NSDate()
  dynamic var plannedStop: NSDate = NSDate()
  dynamic var plannedParticipants: Int = 0
  dynamic var numberOfExamHosts = 0
  
  // user prefs / last used values
  let gdefaults = NSUserDefaults.standardUserDefaults()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    resultsPathTextbox.stringValue   = gdefaults.stringForKey(resultsStoragePathKey)!
    exercisesPathTextbox.stringValue = gdefaults.stringForKey(exercisesStoragePathKey)!
    sshIdentityTextbox.stringValue   = gdefaults.stringForKey(sshIdentityKey)!
    sshUsernameTextbox.stringValue   = gdefaults.stringForKey(sshUsernameKey)!
    plannedStart = gdefaults.valueForKey(plannedStartKey) as NSDate
    plannedStop  = gdefaults.valueForKey(plannedStopKey) as NSDate
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  func numberOfRowsInTableView(aTableView:NSTableView) -> Int {
    return examRoomArray.count
  }
  
  func tableView(tableView: NSTableView!, objectValueForTableColumn tableColumn: NSTableColumn!, row: Int) -> AnyObject! {
    // provide strings for table view room chooser
    var ret : String = "error"
    if (row >= 0 && row < examRoomArray.count) {
      let room = examRoomArray[row] as ExamRoom
      // fixme return pc count for 2nd column here
      switch tableColumn.identifier {
        case "roomName":
          return room.name
        case "roomInfo":
          return "\(room.examHosts.count) seats"
        default:
          return nil
      }
    }
    return ret
  }

  @IBAction func continueToExamatorWindow(sender: AnyObject) {
    gdefaults.setObject(sshIdentityTextbox.stringValue, forKey:sshIdentityKey)
    gdefaults.setObject(sshUsernameTextbox.stringValue, forKey:sshUsernameKey)
    gdefaults.setObject(exercisesPathTextbox.stringValue, forKey:exercisesStoragePathKey)
    gdefaults.setObject(resultsPathTextbox.stringValue, forKey:resultsStoragePathKey)
    gdefaults.setObject(plannedStart, forKey:plannedStartKey)
    gdefaults.setObject(plannedStop, forKey:plannedStopKey)
    
    let dateFormatter = NSDateFormatter()
    dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle // may suck for weird userprefs
    let selectedRooms = myTableView.selectedRowIndexes
    let numSelected = selectedRooms.count
    
    // calculate number of selected seats (room's hosts)
    var totalSeats = 0
    selectedRooms.enumerateIndexesUsingBlock { (idx, _) in
      let item = examRoomArray[idx]
      for (index, host) in enumerate(item.examHosts) {
        totalSeats++
      }
    }
    
    NSLog("%d rooms were selected: %@", numSelected, selectedRooms)
    let startTimeString = dateFormatter.stringFromDate(plannedStart)
    let stopTimeString  = dateFormatter.stringFromDate(plannedStop)
    let alert = NSAlert()
    alert.messageText = "Verify and confirm settings"
    alert.informativeText = " * Starts at \(startTimeString)\n * Ends at \(stopTimeString)\n * \(plannedParticipants) participants\n * \(totalSeats) seats in \(numSelected) room(s)"
    alert.addButtonWithTitle("Wait, what?")
    alert.addButtonWithTitle("Seems legit")

    if (alert.runModal() == NSAlertFirstButtonReturn ||
      numSelected==0 ||
      plannedParticipants==0 ||
      plannedParticipants > totalSeats ||
      startTimeString==stopTimeString ||
      plannedStop < plannedStart) {
      return
    }
    
    // add hosts from selected rooms to collectionView
    selectedRooms.enumerateIndexesUsingBlock { (idx, _) in
      let item = examRoomArray[idx]
      for (index, host) in enumerate(item.examHosts) {
        self.hostArrayCtrl.addObject(host)
      }
    }

    // globally note that settings have been confirmed, worker threads may start
    settingsConfirmed = true
    mainWindow.makeKeyAndOrderFront(self)
    self.view.window?.orderOut(nil)
    self.numberOfExamHosts = totalSeats
  }

  @IBAction func selectSshIdentityFile(sender: AnyObject) {
    var dialog: NSOpenPanel = NSOpenPanel()
    dialog.prompt = "Use selected identity"
    dialog.worksWhenModal = true
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = false
    dialog.canChooseFiles = true
    dialog.resolvesAliases = true
    dialog.title = "Select SSH identity (private key) to use"
    dialog.message = "The public key counterpart must be allowed to log in remotely"
    dialog.runModal()
    var chosenfile = dialog.URL
    if (chosenfile != nil) {
      var TheFile = chosenfile?.path
      sshIdentityTextbox.stringValue = TheFile!
    }
  }
  
  @IBAction func selectExercisesFolder(sender: AnyObject) {
    var dialog: NSOpenPanel = NSOpenPanel()
    dialog.prompt = "Use selected folder"
    dialog.worksWhenModal = true
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = true
    dialog.canChooseFiles = false
    dialog.resolvesAliases = true
    dialog.title = "Select exercises folder for distribution"
    dialog.message = "The folder contents will be transfered, not the folder itself"
    dialog.runModal()
    var chosenfile = dialog.URL
    if (chosenfile != nil) {
      var TheFile = chosenfile?.path
      exercisesPathTextbox.stringValue = TheFile!
    }
  }
  
  @IBAction func selectResultsStorageFolder(sender: AnyObject) {
    var dialog: NSOpenPanel = NSOpenPanel()
    dialog.canCreateDirectories = true
    dialog.prompt = "Use selected folder"
    dialog.worksWhenModal = true
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = true
    dialog.canChooseFiles = false
    dialog.resolvesAliases = true
    dialog.title = "Select folder to store collected results"
    dialog.message = "Folder should reside on fast local disk with enough space left"
    dialog.runModal()
    var chosenfile = dialog.URL
    if (chosenfile != nil) {
      var TheFile = chosenfile?.path
      resultsPathTextbox.stringValue = TheFile!
    }
  }

}
