//
//  MetalView.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import MetalKit
import simd

public class MetalViewDelegate: NSObject, MTKViewDelegate {
    
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
    
    public var device : MTLDevice!
    var vertex_buffer : MTLBuffer!
    var index_buffer : MTLBuffer!
    var rps : MTLRenderPipelineState! = nil
    var uniform_buffer : MTLBuffer!
    
    var kern_buildVertexBuffer : MTLFunction!
    var ps_buildVertexBuffer : MTLComputePipelineState!
    
    var kern_tessellation_quad : MTLFunction!
    var ps_tessellation_quad : MTLComputePipelineState!
    
    var rotY : Float = 30.0
    // This needs to be fixed
    
    override public init() {
        super.init()
        setup()
    }
    
    public func draw(in view: MTKView) {
        update()
        sendToGPU(in : view)    }
    
    func setup() {
        device = MTLCreateSystemDefaultDevice()
        buildVertexBuffer()
        createUniformBuffer()
        registerShaders()
    }
    
    func registerComputerShaders() {
        
    }
    
    func registerShaders() {
        do {
            //library
            //let library = device!.makeDefaultLibrary()
            let path = Bundle.main.path(forResource: "Shaders", ofType: "metal")
            let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            let library = try device!.makeLibrary(source: input, options: nil)
            let vertex_func = library.makeFunction(name: "vertex_func")
            let frag_func = library.makeFunction(name: "fragment_func")
            
            // Setup Vertex Descriptor (stage_in)
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float4;
            vertexDescriptor.attributes[0].offset = 0;
            vertexDescriptor.attributes[0].bufferIndex = 0;
            vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint;
            vertexDescriptor.layouts[0].stepRate = 1;
            vertexDescriptor.layouts[0].stride = 4*MemoryLayout<Float>.size;
            
            //render pipeline descriptor
            let rpld = MTLRenderPipelineDescriptor()
            rpld.vertexFunction = vertex_func
            rpld.vertexDescriptor = vertexDescriptor
            rpld.fragmentFunction = frag_func
            rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            rpld.isTessellationFactorScaleEnabled = false
            rpld.tessellationFactorFormat = .half
            rpld.tessellationControlPointIndexType = .none
            rpld.tessellationFactorStepFunction = .constant
            rpld.tessellationOutputWindingOrder = .clockwise
            rpld.tessellationPartitionMode = .fractionalEven
            rpld.maxTessellationFactor = 64;
        
            try rps = device!.makeRenderPipelineState(descriptor: rpld)
            
            //register build vertex compute shader
            self.kern_buildVertexBuffer = library.makeFunction(name: "kern_buildVertexBuffer")
            do { try ps_buildVertexBuffer = device.makeComputePipelineState(function: kern_buildVertexBuffer) }
            catch { fatalError("buildVertexBuffer computePipelineState failed") }
            
            self.kern_tessellation_quad = library.makeFunction(name: "kern_tessellation_quad")
            do { try ps_tessellation_quad = device.makeComputePipelineState(function: kern_tessellation_quad) }
            catch { fatalError("tessellation_quad computePipelineState failed") }
            
        } catch let error {
            Swift.print("\(error)")
        }
    }
    
    func sendToGPU(in view : MTKView) {
        if let rpd = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandBuffer = device!.makeCommandQueue()?.makeCommandBuffer()
            
            // Tessellation Pass
            //let commandBuffer = commandQueue?.makeCommandBuffer()
            
//            let tessellationFactorsBuffer = device.makeBuffer(length: 256, options: MTLResourceOptions.storageModePrivate)
//            
//            let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
//            computeCommandEncoder?.setComputePipelineState(ps_tessellation_quad!)
//            let edgeFactor: [Float] = [16.0]
//            let insideFactor: [Float] = [8.0]
//            computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
//            computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
//            computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
//            computeCommandEncoder?.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
//            computeCommandEncoder?.endEncoding()
            
            
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd)
            
            //add triangle to encoder
            commandEncoder?.setRenderPipelineState(rps)
            commandEncoder?.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
            commandEncoder?.setVertexBuffer(uniform_buffer, offset: 0, index: 1)
            commandEncoder?.setFrontFacing(.counterClockwise)
            commandEncoder?.setTriangleFillMode(.lines)
//            commandEncoder?.setCullMode(.back)
            
            
            
            commandEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: index_buffer.length / MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: index_buffer, indexBufferOffset: 0)
            
            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
    
    func buildVertexBuffer() {
        let vertexCount = 4
        let vertex_data = [
            Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
            Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [0, 0, 1, 1]),
            Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [1, 1, 1, 1])
//            Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
//            Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 1, 1, 1]),
//            Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [1, 0, 0, 1]),
//            Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 0, 1])
        ]
        vertex_buffer = device!.makeBuffer(bytes: vertex_data, length: MemoryLayout<Vertex>.stride * vertexCount, options: [])
        
        // Populate the indices for the triangles
        let indicesCount = 6
        let index_data: [UInt32] = [
            0, 1, 2, 2, 3, 0,   // front
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
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

}
