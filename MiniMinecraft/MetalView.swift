//
//  MetalView.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

//import Cocoa
import MetalKit
import Dispatch

//import Carbon.HIToolbox.Events
import simd

class MetalView: MTKView {
    
    var commandQueue : MTLCommandQueue! = nil
    
    var capManager : MTLCaptureManager! = nil
    var capScope : MTLCaptureScope! = nil
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
//        self.preferredFramesPerSecond = 60
        device = MTLCreateSystemDefaultDevice()
        RenderManager.sharedInstance.initManager(device!, view: self as MTKView)
        commandQueue = device?.makeCommandQueue()
        self.capManager = MTLCaptureManager.shared()
//        self.capManager.startCapture(commandQueue: commandQueue)
        let commandBuffer = commandQueue.makeCommandBuffer()
        //RenderManager.sharedInstance.buildTessellationFactorsBuffer(commandBuffer: commandBuffer)
        RenderManager.sharedInstance.generateTerrain(commandBuffer: commandBuffer)
        commandBuffer?.commit()
//        self.capManager.stopCapture()
        self.capScope = self.capManager.makeCaptureScope(device: device!)
        self.capScope.label = "draw capture scope"
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        self.capScope.begin()
        let commandBuffer = commandQueue.makeCommandBuffer()
        RenderManager.sharedInstance.draw(commandBuffer: commandBuffer!)
        commandBuffer!.present(currentDrawable!)
        commandBuffer!.commit()
        self.capScope.end()
    }
//
//    override var acceptsFirstResponder: Bool { return true }
//
//    override func keyDown(with event: NSEvent) {
//        switch Int(event.keyCode) {
//        case kVK_ANSI_W:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveForward)
//        case kVK_ANSI_A:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveLeft)
//        case kVK_ANSI_S:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveBackward)
//        case kVK_ANSI_D:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveRight)
//        case kVK_ANSI_Q:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveUp)
//        case kVK_ANSI_Z:
//            RenderManager.sharedInstance.inputEvent(InputCode.camMoveDown)
//        case 123:
//            RenderManager.sharedInstance.inputEvent(InputCode.camRotLeft)
//        case 124:
//            RenderManager.sharedInstance.inputEvent(InputCode.camRotRight)
//        case 125:
//            RenderManager.sharedInstance.inputEvent(InputCode.camRotUp)
//        case 126:
//            RenderManager.sharedInstance.inputEvent(InputCode.camRotDown)
//        case kVK_ANSI_F:
//            RenderManager.sharedInstance.inputEvent(InputCode.freezeFrustrum)
//        default:
//            break;
//        }
//    }
//
//    override func keyUp(with event: NSEvent) {
//        switch Int(event.keyCode) {
//        case kVK_ANSI_W, kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_Q, kVK_ANSI_Z:
//            RenderManager.sharedInstance.inputEvent(InputCode.camDecelerate)
//        case 123, 124, 125, 126:
//            RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
//        default:
//            break;
//        }
//
//    }
}

