//
//  RenderManager.swift
//  MiniMinecraft
//
//  Created by William Ho on 2/25/18.
//  Copyright © 2018 William Ho. All rights reserved.
//


import Cocoa
import MetalKit
import Dispatch

import Carbon.HIToolbox.Events
import simd

struct Uniforms {
    var modelMatrix : float4x4
    var viewProjectionMatrix : float4x4
}

public class RenderManager {
    public static let sharedInstance = RenderManager()
    var device : MTLDevice! = nil
    var library : MTLLibrary?
    
    var vert_func : MTLFunction!
    var frag_func : MTLFunction!
    
    var kern_tessellation : MTLFunction!
    var ps_tessellation : MTLComputePipelineState!
    
    var rps : MTLRenderPipelineState! = nil
    var view : MTKView!
    
    var tessellationFactorsBuffer : MTLBuffer!
    var graphicsBuffer : MTLBuffer!
    var controlPointsIndicesBuffer : MTLBuffer!
    var depthTexture : MTLTexture!
    
    var camera : Camera! = nil
    var velocity : float3 = float3(0.0, 0.0, 0.0)
    var acceleration : float3 = float3(0.0, 0.0, 0.0)
    
    public var terrainManager : TerrainManager! = nil
    
    func initManager(_ device: MTLDevice, view: MTKView) {
        self.view = view
        self.device = device
        self.library = device.makeDefaultLibrary()
        // register shaders
        
        self.camera = Camera(
            fov : 45,
            aspect : 1,
            farClip : 1000,
            nearClip : 0.01,
            pos : [0.0, 12.0, 30.0, 1.0],
            forward : [0.0, 0.0, -1.0],
            right : [1.0, 0.0, 0.0],
            up : [0.0, 1.0, 0.0]
        )
        
        self.terrainManager = TerrainManager(device: device, library: library!, inflightChunksCount: 2)
        
        registerGraphicsShaders()
        buildDepthTexture()
        setUpBuffers()
    }
    
    func draw(commandBuffer : MTLCommandBuffer) {
        update() // Update camera attributes
        
        self.view.depthStencilPixelFormat = .depth32Float
        let renderPassDescriptor = self.view.currentRenderPassDescriptor
        let depthAttachmentDescriptor = MTLRenderPassDepthAttachmentDescriptor()
        depthAttachmentDescriptor.clearDepth = 1.0
        depthAttachmentDescriptor.texture = depthTexture
        renderPassDescriptor?.depthAttachment = depthAttachmentDescriptor
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction(rawValue: 1)! // less case
        depthStencilDescriptor.isDepthWriteEnabled = true
        let depthStencilState = device?.makeDepthStencilState(descriptor : depthStencilDescriptor)
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderCommandEncoder?.setRenderPipelineState(rps!)
        renderCommandEncoder?.setVertexBuffer(graphicsBuffer, offset: 0, index: 1)
        //renderCommandEncoder?.setTriangleFillMode(.lines)
        //renderCommandEncoder?.setCullMode(.back)
        
        
        renderCommandEncoder?.setDepthStencilState(depthStencilState)

        terrainManager.drawTerrain(renderCommandEncoder, tessellationBuffer: tessellationFactorsBuffer)
        
        renderCommandEncoder?.endEncoding()
        commandBuffer.present(self.view.currentDrawable!)
        commandBuffer.commit()
    }
    
    func registerGraphicsShaders() {
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
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
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
            self.view.printView("\(error)")
        }
    }
    
    func buildDepthTexture() {
        let depthStencilTextureDescriptor = MTLTextureDescriptor()
        depthStencilTextureDescriptor.pixelFormat = .depth32Float
        depthStencilTextureDescriptor.width = 2 * Int(self.view.bounds.size.width)
        depthStencilTextureDescriptor.height = 2 * Int(self.view.bounds.size.height)
        depthStencilTextureDescriptor.storageMode = .private
        depthStencilTextureDescriptor.usage = .renderTarget
        depthTexture = device!.makeTexture(descriptor: depthStencilTextureDescriptor)
    }
    
    func buildTessellationFactorsBuffer(commandBuffer : MTLCommandBuffer?) {
        // Tessellation
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(ps_tessellation!)
        let edgeFactor: [Float] = [1.0]
        let insideFactor: [Float] = [1.0]
        computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
        let threadExecutionWidth = ps_tessellation.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: ((16 * 16 * 16 * 6) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
        computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeCommandEncoder?.endEncoding()
    }
    
    func setUpBuffers() {
        tessellationFactorsBuffer = device!.makeBuffer(length: 1024, options: MTLResourceOptions.storageModePrivate)
        graphicsBuffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
    }
    
    func update() {
        updatePhysics()
        
        let bufferPointer = graphicsBuffer.contents()
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
    
    func keyUpEvent(_ event : NSEvent) {
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
    
    func keyDownEvent(_ event : NSEvent) {
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
}
