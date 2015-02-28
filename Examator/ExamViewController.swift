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
  @IBOutlet weak var runCommandMenuEntry: NSMenuItem!
  
  @IBOutlet weak var hostArrayCtrl: NSArrayController!
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  override func viewDidAppear() {
    // called when ExamView window opens after setup confirmation
    super.viewDidAppear()
    // start timers
    NSTimer.scheduledTimerWithTimeInterval(1.00, target: self, selector: "updateClock", userInfo: nil, repeats: true)
    NSTimer.scheduledTimerWithTimeInterval(15.00, target: self, selector: "updateClientStatus", userInfo: nil, repeats: true)
    // gnah... needs to start/stop on checkbox state - otherwise checking will not take instant full backup...
    NSTimer.scheduledTimerWithTimeInterval(120.0, target: self, selector: "runFullBackupLoopIteration", userInfo: nil, repeats: true)
    self.runCommandMenuEntry.hidden = false
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
  
  @IBAction func runRemoteCommandPopup(sender: AnyObject) {
    let alert = NSAlert()
    alert.messageText = "Run remote command"
    alert.informativeText = "Provide command to be executed on selected hosts." +
      "The first line of output will be shown in GUI (notyet)"
    alert.addButtonWithTitle("Wait, what?")
    alert.addButtonWithTitle("Seems legit")

    let textField : NSTextField = NSTextField()
    textField.setFrameSize(NSSize(width: 300, height: 24))
    textField.stringValue = "du -sk results"

    alert.accessoryView = textField
    if (alert.runModal() == NSAlertFirstButtonReturn) {
      // FIXME
      // run sshRemoteExec with textField.stringValue as command
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
      for (host) in hostArray {
        if (host.sshStatus != Int(ServerKeyKnownOK)) {
          // NSLog("SKIP host %@ as not ok state ...", host.hostname)
          continue
        }
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) { // 1
          let diceRollFiles = Int(arc4random_uniform(20))
          host.backupStatusImage = NSImage(named: "wheel.gif")!
          // FIXME
          dispatch_async(dispatch_get_main_queue()) {
            //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
            // if 0 result files present, then orange-x
            host.lastBackup = "\(diceRollFiles) files"
            host.backupStatusImage = NSImage(named: "arrow-down.png")!
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
    for (host) in hostArray {

      dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) {
        host.actionStatusImage = NSImage(named:"wheel.gif")!
        var remoteCommand = "echo -n \"pid $$ on $(hostname) uptime \" ; uptime -s | cut -d' ' -f2"
        let username = self.gdefaults.stringForKey(sshUsernameKey)!
        let res = sshRemoteExec((host.hostname as NSString).UTF8String,(remoteCommand as NSString).UTF8String, (username as NSString).UTF8String )

        dispatch_async(dispatch_get_main_queue()) {
          //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
          host.statusLabelColor = NSColor.redColor()
          host.actionStatusImage = NSImage(named:"status-error.png")!
          host.sshStatus = Int(res)
          switch res {
          case ServerConnectionError:
            host.backupStatus = "No connection"
            host.actionStatusImage = NSImage(named:"status-error.png")!
          case ServerKeyNotKnown:
            host.backupStatus = "Untrusted"
          case ServerKeyError:
            host.backupStatus = "Key error"
          case ServerKeyChanged:
            host.backupStatus = "Key mismatch"
          case ServerKeyFoundOther:
            host.backupStatus = "Other key found"
          case ServerAuthErrorPubKey:
            host.backupStatus = "PubKey error"
          case ServerAuthErrorOther:
            host.backupStatus = "Auth error"
          case ServerSessionInitError:
            host.backupStatus = "Server error"
          case ServerKeyKnownOK:
            host.backupStatus = "SSH OK"
            host.statusLabelColor = NSColor.blackColor()
            host.actionStatusImage = NSImage(named: "success.png")!
            // should update hosts stats label with remoteExec output
          default:
            host.backupStatus = "%-(" // shouldn't happen
          }
        }
      }
    }
  }
}