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
  dynamic var backupStatus = "No backup yet"
  dynamic var lastBackup = "n/a"
  dynamic var sshStatus : Int = -1
  dynamic var statusLabelColor : NSColor = NSColor.blackColor()
  dynamic var room : ExamRoom = ExamRoom()
  dynamic var backupStatusImage: NSImage = NSImage(named: "status-warning.png")!
  dynamic var actionStatusImage: NSImage = NSImage(named: "unknown.png")!
}
