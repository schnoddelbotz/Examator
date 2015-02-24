//
//  ExamViewController.swift
//  Examator
//
//  Created by jan on 17/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//

import Cocoa

class ExamViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  
  dynamic var hostArray: Array<ExamHost> = []
  dynamic var backupLoopEnabled: Bool = false
  let gdefaults = NSUserDefaults.standardUserDefaults()
  var fullBackupRunning: Bool = false
  
  @IBOutlet weak var currentTimeLabel: NSTextField!
  @IBOutlet weak var redBottomMessageLabel: NSTextField!
  @IBOutlet weak var backupLoopCheckbox: NSButton!
  
  @IBOutlet weak var hostArrayCtrl: NSArrayController!
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidAppear() {
    // called when ExamView window opens after setup confirmation
    super.viewDidAppear()
    // start timers
    NSTimer.scheduledTimerWithTimeInterval(1.00, target: self, selector: "updateClock", userInfo: nil, repeats: true)
    NSTimer.scheduledTimerWithTimeInterval(5.00, target: self, selector: "updateClientStatus", userInfo: nil, repeats: true)
    // gnah... needs to start/stop on checkbox state - otherwise checking will not take instant full backup...
    NSTimer.scheduledTimerWithTimeInterval(30.0, target: self, selector: "runFullBackupLoopIteration", userInfo: nil, repeats: true)
  }
  
  func updateClock() {
    let date = NSDate()
    let calendar = NSCalendar.currentCalendar()
    let components = calendar.components(.CalendarUnitHour | .CalendarUnitMinute | .CalendarUnitSecond, fromDate: date)
    let hour = String(format: "%02d", components.hour)
    let minutes = String(format: "%02d", components.minute)
    let seconds = components.second
    if (seconds % 2 == 0) {
     currentTimeLabel.stringValue = "\(hour):\(minutes)"
    } else {
     currentTimeLabel.stringValue = "\(hour).\(minutes)"
    }
  }
  
  func runFullBackupLoopIteration() {
    // this should ...
    // - define a name for current backup folder (timestamped)
    // - verify if the status thread has marked this host for result collection
    // - sshFetchResource() for every ExamHost student result directory
    // - update GUI about individual numFiles/lastBackup

    if (!settingsConfirmed || fullBackupRunning) {
      // it's a bit ugly like this ... would be nicer to start timers when needed
      // fullBackupRunning is NOT working yet!!!
      return
    }
    fullBackupRunning = true
    if (backupLoopCheckbox.state==1) {
      NSLog("FULLBACKUP triggerd, ignoring selection: %@", hostArrayCtrl.selectionIndexes)
      // waiting for incrementals to finish... then
      // foreach client
      for (host) in hostArray {
        // fixme: test if host.clientStatus (notyet) tells us to even try to fetch a backup
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) { // 1
          // exec rsync pull ...
          let diceRoll = useconds_t(arc4random_uniform(5000000))
          let diceRollFiles = Int(arc4random_uniform(20))
          // FIXME
          // this just tests rexec right now
          var remoteCommand = "echo -n \"pid $$ on $(hostname) uptime \" ; uptime -s | cut -d' ' -f2"
          let username = self.gdefaults.stringForKey(sshUsernameKey)!
          let res = sshRemoteExec((host.hostname as NSString).UTF8String,(remoteCommand as NSString).UTF8String, (username as NSString).UTF8String )
          // self.gdefaults.stringForKey(sshUsernameKey)
          dispatch_async(dispatch_get_main_queue()) {
            //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
            host.backupStatus = "x\(diceRoll)"
            host.lastBackup = "\(diceRollFiles) files"
          }
        }
      }
      // how to wait here ... and reset fullBackupRunning = false?
      NSLog("FULLBACKUP going home") // ... but should wait until all done ... how?
    } else {
      NSLog("FULLBACUP **SKIPPED AS DISABLED**")
    }
    // FIXME: wrong time...
    fullBackupRunning = false
    // maybe a fullBackupTar should be triggered here ... good moment + avoid another timer?
  }
  
  func updateClientStatus() {
    // this should ...
    // - sshExec on any host a single status command, collecting (JSON?!)
    //   * memory usage
    //   * cpu usage, uptime
    //   * student user logged in (uname/realname)
    //   * diskfree
    // - update ExamHostItem/display
    // - sets some kind of 'backuploopWorthy' property
    //NSLog("FAKE!")
    /*
    let numHosts = (UInt32)(hostArray.count)
    let diceRoll = Int(arc4random_uniform(numHosts))
    let statusCode = Int(arc4random_uniform(999)) + 1
    hostArray[diceRoll].lastBackup = "\(statusCode) files"
    */
  }
  
}
