//
//  PlatformTypes.swift
//  Landscape-iOS
//
//  Created by William Ho on 4/11/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
    //import Foundation
    import UIKit
    //typealias PlatformView                  = UIView
    //typealias PlatformPoint                 = CGPoint
    typealias PlatformViewController        = UIViewController
//    typealias PlatformPanGestureRecognizer  = UIPanGestureRecognizer
//    typealias PlatformZoomGestureRecognizer = UIPinchGestureRecognizer
#else
    import Cocoa
    import AppKit
    //typealias PlatformView                  = NSView
    //typealias PlatformPoint                 = NSPoint
    typealias PlatformViewController        = NSViewController
//    typealias PlatformPanGestureRecognizer  = NSPanGestureRecognizer
//    typealias PlatformZoomGestureRecognizer = NSMagnificationGestureRecognizer
#endif
