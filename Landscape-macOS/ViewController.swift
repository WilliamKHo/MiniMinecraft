//
//  ViewController.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Metal
import MetalKit
import Carbon.HIToolbox.Events
import Cocoa


class ViewController: PlatformViewController {
    

    var metalView: MTKView?
    
    var commandQueue: MTLCommandQueue?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.metalView = self.view as? MetalView
        self.metalView?.device = MTLCreateSystemDefaultDevice()
        
        if(metalView?.device == nil)
        {
            print("Metal Is Not Supported On This Device");
            return;
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) {
            self.keyUp(with: $0)
            return $0
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
        // Do any additional setup after loading the view.
    }
    
//    override func becomeFirstResponder() -> Bool {
//        return false
//    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_ANSI_W:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveForward)
            
        case kVK_ANSI_A:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveLeft)

        case kVK_ANSI_S:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveBackward)

        case kVK_ANSI_D:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveRight)

        case kVK_ANSI_Q:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveUp)

        case kVK_ANSI_Z:
            RenderManager.sharedInstance.inputEvent(InputCode.camMoveDown)

        case 123:
            RenderManager.sharedInstance.inputEvent(InputCode.camRotLeft)

        case 124:
            RenderManager.sharedInstance.inputEvent(InputCode.camRotRight)

        case 125:
            RenderManager.sharedInstance.inputEvent(InputCode.camRotUp)

        case 126:
            RenderManager.sharedInstance.inputEvent(InputCode.camRotDown)

        case kVK_ANSI_F:
            RenderManager.sharedInstance.inputEvent(InputCode.freezeFrustrum)
        default:
            break;
        }
    }
    
    override func keyUp(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_ANSI_W, kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_Q, kVK_ANSI_Z:
            RenderManager.sharedInstance.inputEvent(InputCode.camDecelerate)
            
        case 123, 124, 125, 126:
            RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
        
        default:
            break;
        }
    }

}

