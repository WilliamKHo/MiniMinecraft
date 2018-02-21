//
//  BufferProvider.swift
//  MiniMinecraft
//
//  Created by William Ho on 2/21/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Cocoa
import Metal

class BufferProvider: NSObject {
    let inflightBufferscount : Int
    private var buffers : [MTLBuffer]
    private var availableBufferIndex : Int
    var availableResourcesSemaphore : DispatchSemaphore
    
    init(device: MTLDevice, inflightBuffersCount: Int, sizeOfBuffer: Int) {
        self.availableResourcesSemaphore = DispatchSemaphore(value: inflightBuffersCount)
        self.inflightBufferscount = inflightBufferscount
        buffers = [MTLBuffer]()
        for _ in 0...inflightBuffersCount-1 {
            let buffer = device.makeBuffer(sizeOfBuffer, options: [])
            buffers.append(buffer)
        }
    }
    
    deinit{
        for _ in 0...self.inflightBuffersCount{
            self.availableResourcesSemaphore.signal()
        }
    }
    
    func nextBuffer() { // Pass in as arguments the data for a chunk
        let buffer = buffers[availableBufferIndex]
        
        let bufferPointer = buffer.contents()
        
        // memcpy
        
        availableBufferIndex += 1
        if availableBufferIndex == inflightBufferscount {
            availableBufferIndex = 0
        }
        return buffer
    }

}
