//
//  ExamHost.swift
//  Examator
//
//  Created by jan on 18/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//

import Cocoa

class ExamHost: NSObject {
  dynamic var hostname = "uninitializedHostname" // IP welcome here, too
  dynamic var username = "unavailable"
  dynamic var userRealname = "Esteban Sanchez-Diaz"
  dynamic var backupStatus = "n/a - wait"
  dynamic var lastBackup = "n/a"
  dynamic var sshStatus : Int = -1
  dynamic var statusLabelColor : NSColor
  dynamic var room : ExamRoom

  dynamic var backupStatusImage: NSImage // -none, -iscurrent, -istooold
  dynamic var actionStatusImage: NSImage // query, runcmd, pushing, pulling, idle
  dynamic var systemStatusImage: NSImage // background: ssh-user-ping-ok, no-ssh, no-ping
  
  override init() {
    backupStatusImage = NSImage(named: "status-warning.png")!
    actionStatusImage = NSImage(named: "unknown.png")!
    systemStatusImage = NSImage(named: "unknown.png")!
    room = ExamRoom()
    statusLabelColor = NSColor.blackColor()
    super.init()
  }
}
