//
//  ExamRoom.swift
//  Examator
//
//  Created by jan on 20/02/15.
//  Copyright (c) 2015 schnoddelbotz. All rights reserved.
//

import Cocoa

class ExamRoom: NSObject {
  var dbId : Int = 0
  var name : String = "noRoomName"
  var hostCount : Int = 0
  var printQueue : String = "noPrintQueue"
  var examHosts: Array<ExamHost> = []
}
