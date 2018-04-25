//
//  RenderManager.swift
//  MiniMinecraft
//
//  Created by William Ho on 2/25/18.
//  Copyright © 2018 William Ho. All rights reserved.
//


//import Cocoa
import MetalKit
import Dispatch

//import Carbon.HIToolbox.Events
import simd

struct Uniforms {
    var modelMatrix : float4x4
    var viewProjectionMatrix : float4x4
    var camPos : float3
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
    var depthStencilState : MTLDepthStencilState!
    
    var camera : Camera! = nil
    
    
    public var terrainManager : TerrainManager! = nil
    
    func initManager(_ device: MTLDevice, view: MTKView) {
        self.view = view
        self.device = device
        self.library = device.makeDefaultLibrary()
        // register shaders
        
        self.camera = Camera(
            fovy : 60,
            aspect : Float(view.frame.size.width / view.frame.size.height),
            farClip : 500,
            nearClip : 0.01,
            pos : [0.0, 12.0, 30.0],
            forward : [0.0, 0.0, -1.0],
            right : [1.0, 0.0, 0.0],
            up : [0.0, 1.0, 0.0]
        )
        
        self.terrainManager = TerrainManager(device: device, library: library!, inflightChunksCount: 350)
        
        registerGraphicsShaders()
        buildDepthTexture()
        setUpBuffers()
    }
    
    func draw(commandBuffer : MTLCommandBuffer) {
        update() // Update camera attributes
        terrainManager.generateTerrain(commandBuffer: commandBuffer, camera: camera)
        
        self.view.depthStencilPixelFormat = .depth32Float
        let renderPassDescriptor = self.view.currentRenderPassDescriptor
        let depthAttachmentDescriptor = MTLRenderPassDepthAttachmentDescriptor()
        depthAttachmentDescriptor.clearDepth = 1.0
        depthAttachmentDescriptor.texture = depthTexture
        renderPassDescriptor?.depthAttachment = depthAttachmentDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 0.5, 1.0)
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderCommandEncoder?.setRenderPipelineState(rps!)
        renderCommandEncoder?.setVertexBuffer(graphicsBuffer, offset: 0, index: 1)
        //renderCommandEncoder?.setTriangleFillMode(.lines)
        renderCommandEncoder?.setCullMode(.back)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)

        terrainManager.drawTerrain(renderCommandEncoder, tessellationBuffer: tessellationFactorsBuffer)
        
        renderCommandEncoder?.endEncoding()
    }
    
    func registerGraphicsShaders() {
//        kern_tessellation = library?.makeFunction(name: "tessellation_kernel_quad")
//        do { try ps_tessellation = device!.makeComputePipelineState(function: kern_tessellation) }
//        catch { fatalError("tessellation_quad computePipelineState failed") }
        
        vert_func = library?.makeFunction(name: "tessellation_vertex_triangle")
        frag_func = library?.makeFunction(name: "tessellation_fragment")
        
        // Setup Vertex Descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].bufferIndex = 0;
        vertexDescriptor.attributes[1].format = .float4;
        vertexDescriptor.attributes[1].offset = 4 * MemoryLayout<Float>.stride;
        vertexDescriptor.attributes[1].bufferIndex = 0;
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint;
        vertexDescriptor.layouts[0].stepRate = 1;
        vertexDescriptor.layouts[0].stride = 8 * MemoryLayout<Float>.stride;
        
        // Setup Render Pipeline
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderPipelineDescriptor.fragmentFunction = frag_func
        renderPipelineDescriptor.isTessellationFactorScaleEnabled = false
        renderPipelineDescriptor.tessellationFactorFormat = .half
        renderPipelineDescriptor.tessellationControlPointIndexType = .none
        renderPipelineDescriptor.tessellationFactorStepFunction = .perPatch
        renderPipelineDescriptor.tessellationOutputWindingOrder = .clockwise
        renderPipelineDescriptor.tessellationPartitionMode = .fractionalEven
        renderPipelineDescriptor.maxTessellationFactor = 16;
        renderPipelineDescriptor.vertexFunction = vert_func
        
        do {
            try rps = device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch let error {
            //self.view.printView("\(error)")
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
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction(rawValue: 1)! // less case
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device?.makeDepthStencilState(descriptor : depthStencilDescriptor)
    }
    
//    func buildTessellationFactorsBuffer(commandBuffer : MTLCommandBuffer?) {
//        // Tessellation
//        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
//        computeCommandEncoder?.setComputePipelineState(ps_tessellation!)
//        let edgeFactor: [Float] = [1.0]
//        let insideFactor: [Float] = [1.0]
//        computeCommandEncoder?.setBytes(edgeFactor, length: MemoryLayout<Float>.size, index: 0)
//        computeCommandEncoder?.setBytes(insideFactor, length: MemoryLayout<Float>.size, index: 1)
//        let threadExecutionWidth = ps_tessellation.threadExecutionWidth
//        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
//        let threadgroupsPerGrid = MTLSize(width: ((16 * 16 * 16 * 3) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
//        computeCommandEncoder?.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
//        computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        computeCommandEncoder?.endEncoding()
//    }
    
    func generateTerrain(commandBuffer : MTLCommandBuffer?) {
        self.terrainManager.generateTerrain(commandBuffer: commandBuffer, camera: camera)
    }
    
    func setUpBuffers() {
        tessellationFactorsBuffer = device!.makeBuffer(length: 16 * 16 * 16 * 3 * 6 * MemoryLayout<UInt16>.stride, options: [])
        graphicsBuffer = device!.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
    }
    
    func update() {
        camera.update()
        
        let bufferPointer = graphicsBuffer.contents()
        var uniforms = Uniforms(
            modelMatrix: simd_rotation(dr: [0, 0, 0]),
            viewProjectionMatrix: camera.computeViewProjectionMatrix(),
            camPos: camera.pos
        )
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.stride)
    }
    
    func inputEvent(_ event : InputCode) {
        switch event {
        case .freezeFrustrum:
            terrainManager.toggleFreeze()
            if (camera.farClip == 500) {
                camera.farClip = 2000
            } else {
                camera.farClip = 500
            }
        default:
            camera.inputEvent(event)
        }
    }
    
    func resize() {
        self.camera.aspect = Float(view.frame.size.width / view.frame.size.height)
        let depthStencilTextureDescriptor = MTLTextureDescriptor()
        depthStencilTextureDescriptor.pixelFormat = .depth32Float
        depthStencilTextureDescriptor.width = 2 * Int(self.view.bounds.size.width)
        depthStencilTextureDescriptor.height = 2 * Int(self.view.bounds.size.height)
        depthStencilTextureDescriptor.storageMode = .private
        depthStencilTextureDescriptor.usage = .renderTarget
        depthTexture = device!.makeTexture(descriptor: depthStencilTextureDescriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction(rawValue: 1)! // less case
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device?.makeDepthStencilState(descriptor : depthStencilDescriptor)
    }
}
