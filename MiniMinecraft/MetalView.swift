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
    
    var commandQueue : MTLCommandQueue!
    var vertex_buffer : MTLBuffer!
    var index_buffer : MTLBuffer!
    var rps : MTLRenderPipelineState! = nil
    var uniform_buffer : MTLBuffer!
    var tessellationFactorsBuffer : MTLBuffer!
    var controlPointsBuffer : MTLBuffer!
    var voxelValuesBuffer : MTLBuffer!
    var faces : Int = 0
    var controlPointsIndicesBuffer : MTLBuffer!
    
    // -------Terrain Generation data
    var voxel_buffer : MTLBuffer!
    
    var kern_computeControlPoints : MTLFunction!
    var ps_computeControlPoints : MTLComputePipelineState!
    //--------End Terrain Generation data
    
    //-------BufferProviders for Terrain
    var terrainBufferProvider : BufferProvider!
    var tessellationBufferProvider : BufferProvider!
    //-------End
    
    var library : MTLLibrary?
    
    var kern_tessellation : MTLFunction!
    var ps_tessellation : MTLComputePipelineState!
    
    var vert_func : MTLFunction!
    var frag_func : MTLFunction!
    
    var depthTexture : MTLTexture!
    
    var rotY : Float = 30.0
    // This needs to be fixed
    
    var chunkDimension: Int = 16
    
    var camera : Camera!
    var velocity : float3 = float3(0.0, 0.0, 0.0)
    var acceleration : float3 = float3(0.0, 0.0, 0.0)
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        //setup Metal
        //setup Compute Pipeline
        //setup Vertex Descriptor and Render pipeline
        self.preferredFramesPerSecond = 60
        
        camera = Camera(
            fov : 45,
            aspect : 1,
            farClip : 1000,
            nearClip : 0.01,
            pos : [0.0, 12.0, 30.0, 1.0],
            forward : [0.0, 0.0, -1.0],
            right : [1.0, 0.0, 0.0],
            up : [0.0, 1.0, 0.0]
        )
        
        device = MTLCreateSystemDefaultDevice()
        registerShaders()
        registerTerrainShaders()
        setUpBuffers()
        setUpTerrainBuffers()
        generateTerrain()
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
        update()
        sendToGPU()
        // draw
    }
    
    func registerShaders() {
        // build depth texture
        let depthStencilTextureDescriptor = MTLTextureDescriptor()
        depthStencilTextureDescriptor.pixelFormat = .depth32Float
        depthStencilTextureDescriptor.width = 2 * Int(self.bounds.size.width)
        depthStencilTextureDescriptor.height = 2 * Int(self.bounds.size.height)
        depthStencilTextureDescriptor.storageMode = .private
        depthStencilTextureDescriptor.usage = .renderTarget
        depthTexture = device!.makeTexture(descriptor: depthStencilTextureDescriptor)
        
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
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
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
        tessellationFactorsBuffer = device!.makeBuffer(length: 1024, options: MTLResourceOptions.storageModePrivate)
        let controlPointPositions: [Float32] = [
            0.5, 0.0, 0.0, 0.0,   // center position
            0.0, 0.0, 0.5, 2.0,
            0.0, 0.5, 0.0, 4.0,
        ]
        controlPointsBuffer = device!.makeBuffer(bytes: controlPointPositions, length: MemoryLayout<Float32>.stride * 12, options: [])
//        var controlPointPositions: [Float32] = []
//        faces = 0
//        for i in 0 ..< 32 {
//            for j in 0 ..< 32 {
//                for k in 0 ..< 32 {
//                    if (i + j + k >= 32) {
//                        var center = float3(Float(i) * 1.0, Float(j) * 1.0, Float(k) * 1.0)
//                        controlPointPositions.append(center.x)
//                        controlPointPositions.append(center.y)
//                        controlPointPositions.append(center.z)
//                        controlPointPositions.append(2.0)
//                        faces += 1
//                    }
//                }
//            }
//        }
//        controlPointsBuffer = device!.makeBuffer(bytes: controlPointPositions, length: MemoryLayout<Float32>.stride * faces * 4, options: [])

        let controlPointIndices: [float3] = [
                float3(0.0, 0.0, -1.0), // +x
                float3(0.0, 1.0, 0.0),
                float3(0.0, 0.0, 1.0), // -x
                float3(0.0, 1.0, 0.0),
                float3(1.0, 0.0, 0.0), // +z
                float3(0.0, 1.0, 0.0),
                float3(-1.0, 0.0, 0.0), // -z
                float3(0.0, 1.0, 0.0),
                float3(0.0, 0.0, 1.0), // +y
                float3(1.0, 0.0, 0.0),
                float3(1.0, 0.0, 0.0), // -y
                float3(0.0, 0.0, 1.0)
        ]
        controlPointsIndicesBuffer = device!.makeBuffer(bytes: controlPointIndices, length: MemoryLayout<float3>.stride * 12, options: [])
        
        let voxelValues: [float3] = [
            float3(-1.0, -1.0, -1.0), //0000
            float3(-1.0, -1.0, 3.0),  //0001
            float3(-1.0, 5.0, -1.0),  //0010
            float3(-1.0, 5.0, 3.0),   //0011
            float3(1.0, -1.0, -1.0),  //0100
            float3(1.0, -1.0, 3.0),   //0101
            float3(1.0, 5.0, -1.0),   //0110
            float3(1.0, 5.0, 3.0),    //0111
            float3(-1.0, -1.0, -1.0), //1000
            float3(-1.0, -1.0, 2.0),  //1001
            float3(-1.0, 4.0, -1.0),  //1010
            float3(-1.0, 4.0, 2.0),   //1011
            float3(0.0, -1.0, -1.0),  //1100
            float3(0.0, -1.0, 2.0),   //1101
            float3(0.0, 4.0, -1.0),   //1110
            float3(0.0, 4.0, 2.0),    //1111
        ]
        voxelValuesBuffer = device!.makeBuffer(bytes: voxelValues, length: MemoryLayout<float3>.stride * 16, options: [])
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
        
        commandQueue = device!.makeCommandQueue()
//        let commandBuffer = commandQueue?.makeCommandBuffer()
//
//        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
//
//
//        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
//        let startPos: [vector_float3] = [vector_float3(0.0, 0.0, 0.0)]
//        computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float3>.size, index: 0)
//        computeCommandEncoder?.setBuffer(voxel_buffer, offset: 0, index: 1)
//        computeCommandEncoder?.setBuffer(voxelValuesBuffer, offset: 0, index: 2)
//        var threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
//        var threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
//        var threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
//        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//
//        // Tessellation
//        computeCommandEncoder?.setComputePipelineState(ps_tessellation!)
//        let edgeFactor: [Float] = [1.0]
//        let insideFactor: [Float] = [1.0]
//        computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
//        computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
//        computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
//        threadExecutionWidth = ps_tessellation.threadExecutionWidth
//        threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
//        threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension * 6) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
//        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        computeCommandEncoder?.endEncoding()
//        commandBuffer?.commit();
        
        let commandBuffer2 = commandQueue?.makeCommandBuffer();
        
        self.depthStencilPixelFormat = .depth32Float
        let renderPassDescriptor = currentRenderPassDescriptor
        let depthAttachmentDescriptor = MTLRenderPassDepthAttachmentDescriptor()
        depthAttachmentDescriptor.clearDepth = 1.0
        depthAttachmentDescriptor.texture = depthTexture
        renderPassDescriptor?.depthAttachment = depthAttachmentDescriptor
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction(rawValue: 1)! // less case
        depthStencilDescriptor.isDepthWriteEnabled = true
        let depthStencilState = device?.makeDepthStencilState(descriptor : depthStencilDescriptor)
        
        let renderCommandEncoder = commandBuffer2?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderCommandEncoder?.setRenderPipelineState(rps!)
        renderCommandEncoder?.setVertexBuffer(uniform_buffer, offset: 0, index: 1)
        renderCommandEncoder?.setVertexBuffer(controlPointsIndicesBuffer, offset: 0, index: 2)
//        renderCommandEncoder?.setTriangleFillMode(.lines)
        //renderCommandEncoder?.setCullMode(.back)
        
        
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        for i in 0..<terrainBufferProvider.buffercount() {
            renderCommandEncoder?.setVertexBuffer(terrainBufferProvider.buffer(at: i), offset: 0, index: 0)
            renderCommandEncoder?.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
            renderCommandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: chunkDimension * chunkDimension * chunkDimension * 6, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        }
        renderCommandEncoder?.endEncoding()
        commandBuffer2?.present(currentDrawable!)
        commandBuffer2?.commit()

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
        updatePhysics()
        rotY = rotY + 1.0
        
        uniform_buffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        let bufferPointer = uniform_buffer.contents()
        var uniforms = Uniforms(
            modelMatrix: simd_rotation(dr: [0, 0, 0]),
            viewProjectionMatrix: camera.computeViewProjectionMatrix()
        )
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
    }
    
    func updatePhysics() {
        let dt : Float = 1.0 / 60.0
        if (length(velocity) > 10.0){
            velocity = normalize(velocity) * 10
        }
        if (length(velocity) > 0.5) {
            velocity *= 0.8
        } else if (length(velocity) < 0.5) {
            velocity = float3(0.0, 0.0, 0.0)
        }
        velocity += dt * acceleration
        camera.pos += float4(velocity.x, velocity.y, velocity.z, 0.0)
    }
    
    func registerTerrainShaders() {
        // setUp Compute Pipeline
        kern_computeControlPoints = library?.makeFunction(name: "kern_computeControlPoints")
        do { try ps_computeControlPoints = device!.makeComputePipelineState(function: kern_computeControlPoints) }
        catch { fatalError("compute control points computePipelineState failed") }
    }
    
    func setUpTerrainBuffers() {
        let bufferLength = chunkDimension * chunkDimension * chunkDimension * 6 * 4; //chunk dimensions * floats4 per voxel
//        voxel_buffer = device!.makeBuffer(length: MemoryLayout<Float32>.stride * bufferLength, options: [])
        self.terrainBufferProvider = BufferProvider(device: self.device!, inflightBuffersCount: 25, sizeOfBuffer: MemoryLayout<Float32>.stride * bufferLength)
        let tessellationFactorsLength = 1024
        self.tessellationBufferProvider = BufferProvider(device: self.device!, inflightBuffersCount: 3, sizeOfBuffer: tessellationFactorsLength)

    }
    
    func generateTerrain() {
//        let commandQueue = device!.makeCommandQueue()
//        let commandBuffer = commandQueue?.makeCommandBuffer()
//
//        // Tessellation
//        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
//        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
//        let startPos: [vector_float3] = [vector_float3(0.0, 0.0, 0.0)]
//        computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float3>.size, index: 0)
//        computeCommandEncoder?.setBuffer(voxel_buffer, offset: 0, index: 1)
//        let threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
//        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
//        let threadgroupsPerGrid = MTLSize(width: ((16 * 16 * 16) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
//        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        computeCommandEncoder?.endEncoding()
        commandQueue = device!.makeCommandQueue()
                let commandBuffer = commandQueue?.makeCommandBuffer()
        
                let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        
        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
        computeCommandEncoder?.setBuffer(voxelValuesBuffer, offset: 0, index: 2)
        var threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
        var threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        var threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
        for i in 0..<terrainBufferProvider.buffercount() {
            let x =  i / 10
            let z = i % 10
            let startPos: [vector_float3] = [vector_float3(Float(chunkDimension * x), 0.0, -Float(chunkDimension * z))]
            let buffer = terrainBufferProvider.buffer(at: i)
            computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float3>.size, index: 0)
            computeCommandEncoder?.setBuffer(buffer, offset: 0, index: 1)
            computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        // Tessellation
        computeCommandEncoder?.setComputePipelineState(ps_tessellation!)
        let edgeFactor: [Float] = [1.0]
        let insideFactor: [Float] = [1.0]
        computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
        threadExecutionWidth = ps_tessellation.threadExecutionWidth
        threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension * 6) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
            computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeCommandEncoder?.endEncoding()
        commandBuffer?.commit();
        
        
        

    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        
        switch Int(event.keyCode) {
        case kVK_ANSI_W:
            acceleration.z = -5
            
        case kVK_ANSI_A:
            acceleration.x = -5

        case kVK_ANSI_S:
            acceleration.z = 5

        case kVK_ANSI_D:
            acceleration.x = 5

            
        default:
            break;
        }

    }
    
    override func keyUp(with event: NSEvent) {
        guard !event.isARepeat else { return }
        
        switch Int(event.keyCode) {
        case kVK_ANSI_W:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_A:
            acceleration = float3(0.0, 0.0, 0.0)

        case kVK_ANSI_S:
            acceleration = float3(0.0, 0.0, 0.0)

        case kVK_ANSI_D:
            acceleration = float3(0.0, 0.0, 0.0)

            
        default:
            break;
        }
        
    }
}

