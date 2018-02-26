//
//  MetalView.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Cocoa
import MetalKit
import Dispatch

import Carbon.HIToolbox.Events
import simd

class MetalView: MTKView {
    
    var commandQueue : MTLCommandQueue! = nil
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.preferredFramesPerSecond = 60
        device = MTLCreateSystemDefaultDevice()
        RenderManager.sharedInstance.initManager(device!, view: self as MTKView)
        commandQueue = device?.makeCommandQueue()
        let commandBuffer = commandQueue.makeCommandBuffer()
        RenderManager.sharedInstance.buildTessellationFactorsBuffer(commandBuffer: commandBuffer)
        RenderManager.sharedInstance.generateTerrain(commandBuffer: commandBuffer)
        commandBuffer?.commit()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        let commandBuffer = commandQueue.makeCommandBuffer()
        RenderManager.sharedInstance.draw(commandBuffer: commandBuffer!)
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        RenderManager.sharedInstance.keyDownEvent(event)
    }
    
    override func keyUp(with event: NSEvent) {
        RenderManager.sharedInstance.keyUpEvent(event)
    }
    
}

