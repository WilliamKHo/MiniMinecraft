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
    
    var capManager : MTLCaptureManager! = nil
    var capScope : MTLCaptureScope! = nil
    
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
        self.capManager = MTLCaptureManager.shared()
        self.capScope = self.capManager.makeCaptureScope(device: device!)
        self.capScope.label = "draw capture scope"
        
        var pos0 = float3(0.2, 0.1, 0.3);
        var pos1 = float3(1.0, 12.0, 1.0);
        var perlin0 = perlin(pos: pos0);
        var perlin1 = perlin(pos: pos1);
        var blah = perlin0 + perlin1
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        self.capScope.begin()
        let commandBuffer = commandQueue.makeCommandBuffer()
        RenderManager.sharedInstance.draw(commandBuffer: commandBuffer!)
        commandBuffer!.present(currentDrawable!)
        commandBuffer!.commit()
        self.capScope.end()
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        RenderManager.sharedInstance.keyDownEvent(event)
    }
    
    override func keyUp(with event: NSEvent) {
        RenderManager.sharedInstance.keyUpEvent(event)
    }
    
}

