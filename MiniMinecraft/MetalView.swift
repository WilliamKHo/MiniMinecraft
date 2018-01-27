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
    var tessellationFactorsBuffer : MTLBuffer!
    var controlPointsBuffer : MTLBuffer!
    
    var library : MTLLibrary?
    
    var kern_tessellation : MTLFunction!
    var ps_tessellation : MTLComputePipelineState!
    
    var vert_func : MTLFunction!
    var frag_func : MTLFunction!
    
    var rotY : Float = 30.0
    // This needs to be fixed
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        //setup Metal
        //setup Compute Pipeline
        //setup Vertex Descriptor and Render pipeline
        device = MTLCreateSystemDefaultDevice()
        registerShaders()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        render()
//        update()
    }
    
    func render() {
//        buildVertexBuffer()
//        createUniformBuffer()
//        sendToGPU()
        // setup Buffers
        setUpBuffers()
        update()
        sendToGPU()
        // draw
    }
    
    func registerShaders() {
        //library
        library = device!.makeDefaultLibrary()
        
        // setUp Compute Pipeline
        kern_tessellation = library?.makeFunction(name: "tessellation_kernel_quad")
        do { try ps_tessellation = device!.makeComputePipelineState(function: kern_tessellation) }
        catch { fatalError("tessellation_quad computePipelineState failed") }
        
        vert_func = library?.makeFunction(name: "tessellation_vertex_quad")
        frag_func = library?.makeFunction(name: "tessellation_fragment")
        
        // Setup Vertex Descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].bufferIndex = 0;
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint;
        vertexDescriptor.layouts[0].stepRate = 1;
        vertexDescriptor.layouts[0].stride = 4*MemoryLayout<Float>.size;
        
        // Setup Render Pipeline
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        renderPipelineDescriptor.fragmentFunction = frag_func
        renderPipelineDescriptor.isTessellationFactorScaleEnabled = false
        renderPipelineDescriptor.tessellationFactorFormat = .half
        renderPipelineDescriptor.tessellationControlPointIndexType = .none
        renderPipelineDescriptor.tessellationFactorStepFunction = .constant
        renderPipelineDescriptor.tessellationOutputWindingOrder = .clockwise
        renderPipelineDescriptor.tessellationPartitionMode = .fractionalEven
        renderPipelineDescriptor.maxTessellationFactor = 64;
        renderPipelineDescriptor.vertexFunction = vert_func
        do {
            try rps = device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch let error {
            self.printView("\(error)")
        }
    }
    
    func setUpBuffers() {
        tessellationFactorsBuffer = device!.makeBuffer(length: 256, options: MTLResourceOptions.storageModePrivate)
        let controlPointPositions: [Float] = [
            0.0, 0.0, 0.0, 1.0,   // center position
        ]
        controlPointsBuffer = device!.makeBuffer(bytes: controlPointPositions, length: MemoryLayout<Float>.stride * 16, options: [])
    }
    
    func sendToGPU() {
//        if let rpd = currentRenderPassDescriptor, let drawable = currentDrawable {
//            let commandBuffer = device!.makeCommandQueue()?.makeCommandBuffer()
//            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd)
//
//            //add triangle to encoder
//            commandEncoder?.setRenderPipelineState(rps)
//            commandEncoder?.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
//            commandEncoder?.setVertexBuffer(uniform_buffer, offset: 0, index: 1)
//            commandEncoder?.setFrontFacing(.counterClockwise)
//            commandEncoder?.setCullMode(.back)
//            commandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: index_buffer.length / MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: index_buffer, indexBufferOffset: 0)
//
//            commandEncoder?.endEncoding()
//            commandBuffer?.present(drawable)
//            commandBuffer?.commit()
//        }
        
        let commandQueue = device!.makeCommandQueue()
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        // Tessellation
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(ps_tessellation!)
        let edgeFactor: [Float] = [1.0]
        let insideFactor: [Float] = [1.0]
        computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
        computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
        computeCommandEncoder?.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        computeCommandEncoder?.endEncoding()
        
        let renderPassDescriptor = currentRenderPassDescriptor
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderCommandEncoder?.setRenderPipelineState(rps!)
        renderCommandEncoder?.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)
        renderCommandEncoder?.setVertexBuffer(uniform_buffer, offset: 0, index: 1)
        //renderCommandEncoder?.setTriangleFillMode(.lines)
        renderCommandEncoder?.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
        renderCommandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: 1, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        renderCommandEncoder?.endEncoding()
        
        commandBuffer?.present(currentDrawable!)
        commandBuffer?.commit()

    }
    
    func buildVertexBuffer() {
//        let vertexCount = 8
//        let vertex_data = [
//            Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
//            Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
//            Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [0, 0, 1, 1]),
//            Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [1, 1, 1, 1]),
//            Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
//            Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 1, 1, 1]),
//            Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [1, 0, 0, 1]),
//            Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 0, 1])
//        ]
//        vertex_buffer = device!.makeBuffer(bytes: vertex_data, length: MemoryLayout<Vertex>.stride * vertexCount, options: [])
//
//        // Populate the indices for the triangles
//        let indicesCount = 36
//        let index_data: [UInt32] = [
//            0, 1, 2, 2, 3, 0,   // front
//
//            1, 5, 6, 6, 2, 1,   // right
//
//            3, 2, 6, 6, 7, 3,   // top
//
//            4, 5, 1, 1, 0, 4,   // bottom
//
//            4, 0, 3, 3, 7, 4,   // left
//
//            7, 6, 5, 5, 4, 7,   // back
//        ]
//        index_buffer = device!.makeBuffer(bytes: index_data, length: MemoryLayout<UInt32>.stride * indicesCount, options: [])
    }
    
    func createUniformBuffer() {
//        let camera = Camera(
//            fov : 45,
//            aspect : 1,
//            farClip : 100,
//            nearClip : 0.01,
//            pos : [0.0, 0.0, 30.0, 1.0],
//            forward : [0.0, 0.0, -1.0],
//            right : [1.0, 0.0, 0.0],
//            up : [0.0, 1.0, 0.0]
//        )
//        uniform_buffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
//        let bufferPointer = uniform_buffer.contents()
//        var uniforms = Uniforms(
//            modelMatrix: simd_rotation(dr: [30, rotY, 30]),
//            viewProjectionMatrix: camera.computeViewProjectionMatrix()
//        )
//        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
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

