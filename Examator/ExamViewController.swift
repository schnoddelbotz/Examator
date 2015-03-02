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
  var backupTimer : NSTimer = NSTimer()
  var statusTimer : NSTimer = NSTimer()
  var pStart : NSDate = NSDate() // why not access SVC.plannedStart?
  var pStop  : NSDate = NSDate()
  var actualStart : NSDate = NSDate()
  var actualpStop : NSDate = NSDate() // planned stop using actual start + plantime
  var actualStop : NSDate = NSDate()
  var totalMinutes : Int = 0
  var examStarted = false

  @IBOutlet weak var currentTimeLabel: NSTextField!
  @IBOutlet weak var redBottomMessageLabel: NSTextField!
  @IBOutlet weak var backupLoopCheckbox: NSButton!
  @IBOutlet weak var runCommandMenuEntry: NSMenuItem!
  @IBOutlet weak var nextBackupCountdownLabel: NSTextField!
  @IBOutlet weak var timeLeftLabel: NSTextField!
  @IBOutlet weak var hostArrayCtrl: NSArrayController!
  @IBOutlet weak var actionsMenuItem: NSMenuItem!

  @IBOutlet weak var beginExamButton: NSButton!
  @IBOutlet weak var stopExamButton: NSButton!
  @IBOutlet weak var actualStartTimeLabel: NSTextField! // not bound ...
  @IBOutlet weak var actualStopTimeLabel: NSTextField!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewDidAppear() {
    // called when ExamView window opens after setup confirmation
    super.viewDidAppear()
    // start timers
    NSTimer.scheduledTimerWithTimeInterval(1.00, target: self, selector: "updateClock", userInfo: nil, repeats: true)
    statusTimer = NSTimer.scheduledTimerWithTimeInterval(15.00, target: self, selector: "updateClientStatus", userInfo: nil, repeats: true)
    // gnah... needs to start/stop on checkbox state - otherwise checking will not take instant full backup...
    backupTimer = NSTimer.scheduledTimerWithTimeInterval(120.0, target: self, selector: "runFullBackupLoopIteration", userInfo: nil, repeats: true)
    self.runCommandMenuEntry.hidden = false
    //self.nextBackupCountdownLabel.hidden = true
    pStart = self.gdefaults.valueForKey(plannedStartKey) as NSDate
    pStop  = self.gdefaults.valueForKey(plannedStopKey) as NSDate
    totalMinutes = Int(pStop.timeIntervalSinceDate(pStart)/60)
    let dateFormatter = NSDateFormatter()
    dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
    self.actionsMenuItem.hidden = false
    actualStartTimeLabel.stringValue = "-"
    actualStopTimeLabel.stringValue = "-"
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
    //
    let nextBackupInSeconds = Int(backupTimer.fireDate.timeIntervalSinceDate(date))
    nextBackupCountdownLabel.stringValue = "Next backup in \(nextBackupInSeconds) seconds"

    // update "time left" label -- FIXME not sane yet...
    if (!examStarted) {
      let leftSeconds = Int(pStart.timeIntervalSinceDate(date))
      let leftMinutes = Int(leftSeconds/60)
      if (leftSeconds > 0) {
        timeLeftLabel.textColor = NSColor.greenColor() // tooo light
        timeLeftLabel.stringValue = "\(leftMinutes) minutes left to planned start" // ?
      } else {
        timeLeftLabel.stringValue = "planned start was \(abs(leftSeconds)) seconds ago"
        timeLeftLabel.textColor = NSColor.redColor()
      }
    } else {
      let leftSeconds = Int(actualpStop.timeIntervalSinceDate(date))
      let leftMinutes = Int(leftSeconds/60)
      if (leftSeconds>0) {
        timeLeftLabel.stringValue = "\(leftMinutes) of \(totalMinutes) minutes left"
      } else {
        timeLeftLabel.stringValue = "Time is over!"
        timeLeftLabel.textColor = NSColor.redColor()
      }
    }
  }

  @IBAction func triggerStatusUpdate(sender: AnyObject) {
    // instead of fire(), as it seems to reseat next call
    statusTimer.fireDate = NSDate()
  }

  @IBAction func triggerBackupRun(sender: AnyObject) {
    backupTimer.fireDate = NSDate()
  }

  @IBAction func beginExamTime(sender: AnyObject) {
    examStarted = true
    stopExamButton.enabled = true
    actualStart = NSDate()
    actualpStop = actualStart.dateByAddingTimeInterval(Double(totalMinutes)*60)

    let calendar = NSCalendar.currentCalendar()
    var components = calendar.components(.CalendarUnitHour | .CalendarUnitMinute | .CalendarUnitSecond, fromDate: actualStart)
    var hour = String(format: "%02d", components.hour)
    var minutes = String(format: "%02d", components.minute)
    actualStartTimeLabel.stringValue = "\(hour):\(minutes)"
    components = calendar.components(.CalendarUnitHour | .CalendarUnitMinute | .CalendarUnitSecond, fromDate: actualpStop)
    hour = String(format: "%02d", components.hour)
    minutes = String(format: "%02d", components.minute)
    actualStopTimeLabel.stringValue = "\(hour):\(minutes)"
    timeLeftLabel.textColor = NSColor.blackColor()
  }

  @IBAction func stopExamTime(sender: AnyObject) {
    actualStop = NSDate()
    backupLoopEnabled = false
  }

  @IBAction func selectAllClients(sender: AnyObject) {
    let itemCount = hostArrayCtrl.arrangedObjects.count
    let allItems = NSIndexSet(indexesInRange: NSMakeRange(0, itemCount))
    hostArrayCtrl.setSelectionIndexes(allItems)
  }

  @IBAction func pushExercises(sender: AnyObject) {
    // push exercises
    // ensure selection-or-all / or cancel via alert panel
    // enable 'begin exam' (time) button
    NSLog("PUSH exercises via libssh-scp-r to: %@", hostArrayCtrl.selectionIndexes)
    beginExamButton.enabled = true
  }

  @IBAction func runRemoteCommandPopup(sender: AnyObject) {
    if (hostArrayCtrl.selectedObjects.count==0) {
      // only works with/on selected hosts
      return
    }
    let alert = NSAlert()
    alert.messageText = "Run remote command"
    alert.informativeText = "Provide command to be executed on selected hosts." +
      "The first line of output will be shown in GUI (notyet)"

    alert.addButtonWithTitle("Seems legit")
    alert.addButtonWithTitle("Wait, what?")

    let textField : NSTextField = NSTextField()
    textField.setFrameSize(NSSize(width: 300, height: 24))
    textField.stringValue = "du -sk results"

    alert.accessoryView = textField
    if (alert.runModal() == NSAlertFirstButtonReturn) {
      NSLog("Will execute custom command: %@", textField.stringValue)

      let remoteUsername = self.gdefaults.stringForKey(sshUsernameKey)! as NSString
      let remoteCommandString  = textField.stringValue

      for (host:ExamHost) in hostArrayCtrl.selectedObjects as Array {
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) {
          host.actionStatusImage = NSImage(named:"wheel.gif")!

          let bufferSize = 32768 // FIXME FIXME FIXME ... let's crash if too small.
          var buffer = Array<UInt8>(count: bufferSize, repeatedValue: 0)
          var retSize = UInt32(0)
          let res = sshRemoteExec((host.hostname as NSString).UTF8String,remoteCommandString, (remoteUsername as NSString).UTF8String, &buffer, &retSize )

          dispatch_async(dispatch_get_main_queue()) {
            //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
            host.statusLabelColor = NSColor.redColor()
            host.actionStatusImage = NSImage(named:"status-error.png")!
            host.sshStatus = Int(res) // bug
            if (res == ServerKeyKnownOK) {
              let data = NSData(bytes: buffer, length: Int(retSize))
              let str = NSString(data: data, encoding: NSUTF8StringEncoding)
              //println("Received \(str!.length) / \(retSize) : \(str!)")
              host.statusLabelColor = NSColor.blackColor()
              host.actionStatusImage = NSImage(named:"success.png")!
              // fixme .sh retval?
              // fixme ... handle long/multi-line output ...?
              host.backupStatus = str!
            }
          }
        }
      }
    }
  }

  func runFullBackupLoopIteration() {
    // this should ...
    // - define a name for current backup folder (timestamped)
    // - sshFetchResource() for every ExamHost student result directory
    if (!settingsConfirmed || fullBackupRunning) {
      // it's a bit ugly like this ... would be nicer to start timers when needed
      // fullBackupRunning is NOT working yet!!!
      return
    }
    fullBackupRunning = true
    if (backupLoopCheckbox.state==1) {
      NSLog("FULLBACKUP triggerd (ignoring selection)"/*, hostArrayCtrl.selectionIndexes*/)
      // waiting for incrementals to finish... then
      for (host) in hostArray {
        if (host.sshStatus != Int(ServerKeyKnownOK)) {
          //NSLog("SKIP host %@ as not in OK state ...", host.hostname)
          // hack warning: this is also true if no student is logged in
          continue
        }
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) { // 1
          let diceRollFiles = Int(arc4random_uniform(20))
          host.backupStatusImage = NSImage(named: "wheel.gif")!
          // FIXME
          dispatch_async(dispatch_get_main_queue()) {
            //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
            let nowTime = NSDate()
            let calendar = NSCalendar.currentCalendar()
            let components = calendar.components(.CalendarUnitHour | .CalendarUnitMinute | .CalendarUnitSecond, fromDate: nowTime)
            let nowString = String(format: "%02d:%02d:%02d", components.hour, components.minute, components.second)
            // if 0 result files present, then orange-x
            host.lastBackup = "\(diceRollFiles) files"
            host.backupStatus = "\(nowString)"
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
    // triggered by timer, polls infos from all clients

    let remoteUsername = self.gdefaults.stringForKey(sshUsernameKey)! as NSString
    var remoteCommand = "diskfree=`df -h ~ | tail -1 | awk '{print $4}'`;"
    remoteCommand += "[ -f ~/.exam-setup-user ] && . ~/.exam-setup-user ;"
    remoteCommand += "memfree=`cat /proc/meminfo | grep MemFree | awk '{print $2}'`;"
    remoteCommand += "numresults=$((`find results -type f 2>/dev/null | wc -l`));"
    remoteCommand += "echo -n '{';"
    remoteCommand += "echo -n '\"hostname\":\"'${HOSTNAME}'\",';"
    remoteCommand += "echo -n '\"realname\":\"'${REALNAME}'\",';"
    remoteCommand += "echo -n '\"username\":\"'${LOGINNAME}'\",';"
    remoteCommand += "echo -n '\"diskfree\":\"'${diskfree}'\",';"
    remoteCommand += "echo -n '\"memfree\":\"'${memfree}'\",';"
    remoteCommand += "echo -n '\"numresults\":\"'${numresults}'\"';"
    remoteCommand += "echo -n '}'"
    let remoteCommandString : NSString = remoteCommand as NSString

    for (host) in hostArray {

      dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_UTILITY.value), 0)) {
        host.actionStatusImage = NSImage(named:"wheel.gif")!

        let bufferSize = 256
        var buffer = Array<UInt8>(count: bufferSize, repeatedValue: 0)
        var retSize = UInt32(0)

        let res = sshRemoteExec((host.hostname as NSString).UTF8String,remoteCommandString.UTF8String, remoteUsername.UTF8String, &buffer, &retSize )

        dispatch_async(dispatch_get_main_queue()) {
          //NSLog("Back from \(host.hostname) to mainthread - ret \(res)")
          host.statusLabelColor = NSColor.redColor()
          host.actionStatusImage = NSImage(named:"status-error.png")!
          host.sshStatus = Int(res) // bug
          if (res == ServerKeyKnownOK) {
            var parseError: NSError?
            let data = NSData(bytes: buffer, length: Int(retSize))
            //let str = NSString(data: data, encoding: NSUTF8StringEncoding)
            //println("Received \(str!.length) / \(retSize) : \(str!)")
            //{"hostname":"nas","realname":"Schnoddelbotz","username":"hacker","diskfree":"943G","memfree":"4188648","numresults":"0"}
            let jsonData : AnyObject? = NSJSONSerialization.JSONObjectWithData(data,
              options: NSJSONReadingOptions.AllowFragments, error: &parseError)
            if ((parseError) != nil) {
              NSLog("JSON ERROR on %@ : %@",host.hostname, parseError!);
            }
            else if let json = jsonData as? NSDictionary {
              if let username = json["username"] as? String {
                if let realname = json["realname"] as? String {
                  if (realname != "") {
                    host.userRealname = realname
                    host.username = username
                  } else {
                    host.username = "Nobody"
                    host.backupStatusImage = NSImage()
                    host.sshStatus = -5 /// FIXME ... just skip backup by being non-0
                  }
                }
              }
              if let memfree = json["memfree"] as? String {
                if let diskfree = json["diskfree"] as? String {
                  if let numresults = json["numresults"] as? String {
                    //host.lastBackup = "M:\(memfree) D:\(diskfree) #:\(numresults)"
                    host.lastBackup = "\(numresults) results, free:\(diskfree)"
                  }
                }
              }
            }
          }
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
            //host.backupStatus = "SSH OK"
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