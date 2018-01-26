//
//  MetalView.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Cocoa
import MetalKit
import simd

class MetalView: MTKView {
    
    struct Vertex {
        var position : vector_float4
        var color : vector_float4
        init(pos : vector_float4, col : vector_float4) {
            self.position = pos
            self.color = col
        }
    }
    
    struct Uniforms {
        var modelMatrix : float4x4
        var viewProjectionMatrix : float4x4
    }
    
    var vertex_buffer : MTLBuffer!
    var index_buffer : MTLBuffer!
    var rps : MTLRenderPipelineState! = nil
    var uniform_buffer : MTLBuffer!
    
    var rotY : Float = 30.0
    // This needs to be fixed
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        render()
        update()
    }
    
    func render() {
        buildVertexBuffer()
        createUniformBuffer()
        registerShaders()
        sendToGPU()
    }
    
    func registerShaders() {
        //library
        let library = device!.makeDefaultLibrary()
        let vertex_func = library?.makeFunction(name: "vertex_func")
        let frag_func = library?.makeFunction(name: "fragment_func")
        
        //render pipeline descriptor
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            try rps = device!.makeRenderPipelineState(descriptor: rpld)
        } catch let error {
            self.printView("\(error)")
        }
    }
    
    func sendToGPU() {
        if let rpd = currentRenderPassDescriptor, let drawable = currentDrawable {
            let commandBuffer = device!.makeCommandQueue()?.makeCommandBuffer()
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd)
            
            //add triangle to encoder
            commandEncoder?.setRenderPipelineState(rps)
            commandEncoder?.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
            commandEncoder?.setVertexBuffer(uniform_buffer, offset: 0, index: 1)
            commandEncoder?.setFrontFacing(.counterClockwise)
            commandEncoder?.setCullMode(.back)
            commandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: index_buffer.length / MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: index_buffer, indexBufferOffset: 0)
            
            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
    
    func buildVertexBuffer() {
        let vertexCount = 8
        let vertex_data = [
            Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
            Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [0, 0, 1, 1]),
            Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [1, 1, 1, 1]),
            Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
            Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 1, 1, 1]),
            Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 0, 1])
        ]
        vertex_buffer = device!.makeBuffer(bytes: vertex_data, length: MemoryLayout<Vertex>.stride * vertexCount, options: [])
        
        // Populate the indices for the triangles
        let indicesCount = 36
        let index_data: [UInt32] = [
            0, 1, 2, 2, 3, 0,   // front
            
            1, 5, 6, 6, 2, 1,   // right

            3, 2, 6, 6, 7, 3,   // top

            4, 5, 1, 1, 0, 4,   // bottom

            4, 0, 3, 3, 7, 4,   // left

            7, 6, 5, 5, 4, 7,   // back
        ]
        index_buffer = device!.makeBuffer(bytes: index_data, length: MemoryLayout<UInt32>.stride * indicesCount, options: [])
    }
    
    func createUniformBuffer() {
        let camera = Camera(
            fov : 45,
            aspect : 1,
            farClip : 100,
            nearClip : 0.01,
            pos : [0.0, 0.0, 30.0, 1.0],
            forward : [0.0, 0.0, -1.0],
            right : [1.0, 0.0, 0.0],
            up : [0.0, 1.0, 0.0]
        )
        uniform_buffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        let bufferPointer = uniform_buffer.contents()
        var uniforms = Uniforms(
            modelMatrix: simd_rotation(dr: [30, rotY, 30]),
            viewProjectionMatrix: camera.computeViewProjectionMatrix()
        )
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
    }
    
    func update() {
        rotY = rotY + 1.0
        let camera = Camera(
            fov : 45,
            aspect : 1,
            farClip : 100,
            nearClip : 0.01,
            pos : [0.0, 0.0, 30.0, 1.0],
            forward : [0.0, 0.0, -1.0],
            right : [1.0, 0.0, 0.0],
            up : [0.0, 1.0, 0.0]
        )
        uniform_buffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        let bufferPointer = uniform_buffer.contents()
        var uniforms = Uniforms(
            modelMatrix: simd_rotation(dr: [30, rotY, 30]),
            viewProjectionMatrix: camera.computeViewProjectionMatrix()
        )
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
    }
}

