//
//  AppDelegate.swift
//  Examator
//
//  Created by jan on 17/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//

import Cocoa
// import Swift <- cmd/alt-click ... e.g. find()!
// log NSSystemClockDidChangeNotification ?

// app-global variables
let resultsStoragePathKey   = "resultsStoragePath"
let exercisesStoragePathKey = "exercisesStoragePath"
let sshUsernameKey = "sshUsername"
let sshIdentityKey = "sshIdentity"
let idKey = "id"
let nameKey = "name"
let plannedStartKey = "plannedStart"
let plannedStopKey = "plannedStop"
var settingsConfirmed : Bool = false
var examRoomArray : [ExamRoom] = []

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    // Insert code here to initialize your application
  }
  
  override init() {
    super.init()
    let infoDict : NSDictionary = NSBundle.mainBundle().infoDictionary!
    if let versionString = infoDict["CFBundleShortVersionString"] as? String {
      NSLog("Examator version %@ AppDelegate:init()",versionString)
    }
    
    // to showcase working libssh C bridge...
    initLibSSH()
    let sshCopyright = String.fromCString(getSSHCopyrightString())
    NSLog("Examator ships with libssh -- copyright notice:")
    NSLog("libssh %@", sshCopyright!)
    
    // set defaults for empty startup preferences
    let udefaults = NSMutableDictionary()
    udefaults.setObject("~/collected-results", forKey:resultsStoragePathKey)
    udefaults.setObject("~/exam-tasks-and-resources", forKey:exercisesStoragePathKey)
    udefaults.setObject("student", forKey:sshUsernameKey)
    udefaults.setObject("~/.ssh/id_dsa", forKey:sshIdentityKey)
    udefaults.setObject(NSDate(), forKey: plannedStartKey)
    udefaults.setObject(NSDate(), forKey: plannedStopKey)
    NSUserDefaults.standardUserDefaults().registerDefaults(udefaults)
    loadBundledJSONRoomdata()
  }
  
  func loadBundledJSONRoomdata() {
    let jsonPath = String(format: "%@%@",
      NSBundle.mainBundle().bundlePath, "/Contents/Resources/roomdata.json")
    let jsonRaw = NSData(contentsOfFile:jsonPath, options:nil, error: nil)
    let jsonData : AnyObject? = NSJSONSerialization.JSONObjectWithData(jsonRaw!,
      options: NSJSONReadingOptions.AllowFragments, error: nil)
    
    if let json = jsonData as? NSDictionary {
      if let rooms = json["rooms"] as? NSArray {
        importRoomdata(rooms)
      }
      if let hosts = json["hosts"] as? NSArray {
        importHostdata(hosts)
      }
    }
    //NSLog("Rooms: %@", examRoomArray)
  }
  
  func importRoomdata(rooms: NSArray) -> Void {
    for (index, room) in enumerate(rooms) {
      //  println("Room \(index): \(room)")
      if let children = room["children"] as? NSArray {
        // only operate on leaf nodes, i.e. rooms, not OUs -- flattens
        if (children.count==0) {
          let newRoom = ExamRoom()
          // fixme: string inside json!
          if let id = room["id"] as? String {
            newRoom.dbId = id.toInt()!
            if let name = room["name"] as? String {
              newRoom.name = name
              examRoomArray.append(newRoom)
            }
          }
        }
      }
    }
  }
  
  func importHostdata(hosts: NSArray) -> Void {
    //        hostDictionary = hosts ... "ou_id" = int, hostname
    //    NSLog("HOSTS ... %@ ...", hosts)
    for (index, host) in enumerate(hosts) {
      //println("Item \(index): \(host)")
      if let h = host["hostname"] as? String {
        if let ou = host["ou_id"] as? String {
          let roomObj = getExamRoomByDbId(ou.toInt()!)
          var newHost = ExamHost()
          newHost.hostname = h
          newHost.room = roomObj
          //NSLog("Got ROOM %@ for host %@ in roomDbId %@", roomObj, h, ou)
          roomObj.examHosts.append(newHost)
        }
      }
    }
  }
  
  func getExamRoomByDbId(searchId: Int) -> ExamRoom {
    // come on ... a but more sophisticated, please :-)
    // http://digitalleaves.com/blog/2014/11/membership-of-custom-objects-in-swift-arrays-and-dictionaries/
    for (index, r) in enumerate(examRoomArray) {
      if (r.dbId==searchId) {
        return r
      }
    }
    NSLog("FIXME: FAILED getExamRoomByDbId lookup!")
    return ExamRoom()
  }
  
  // any window that has its delegate bound here will show this dialog ...
  // fixme: does not catch cmd-q; fixed by removing key+menu entry in app menu
  func windowShouldClose(id: AnyObject) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Really quit examator?"
    alert.informativeText = "You may restart later but timers will be lost"
    alert.addButtonWithTitle("Wait, what?")
    alert.addButtonWithTitle("Really quit")
    if (alert.runModal() == NSAlertFirstButtonReturn) {
      return false
    }
    return true
  }
  
  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
    NSLog("Teardown!")
    shutdownLibSSH()
  }
  
  func applicationShouldTerminateAfterLastWindowClosed(theApplication: NSApplication) -> Boolean {
    return 1
  }
  
}


// oh my beautiful swift ... and thanks no. 1000, stackoverflow.com!
// http://stackoverflow.com/questions/26198526/nsdate-comparison-using-swift
public func ==(lhs: NSDate, rhs: NSDate) -> Bool {
  return lhs === rhs || lhs.compare(rhs) == .OrderedSame
}

public func <(lhs: NSDate, rhs: NSDate) -> Bool {
  return lhs.compare(rhs) == .OrderedAscending
}

extension NSDate: Comparable { }