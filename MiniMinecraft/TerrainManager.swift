//
//  TerrainManager.swift
//  MiniMinecraft
//
//  Created by William Ho on 2/25/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import MetalKit
import Dispatch

import Carbon.HIToolbox.Events
import simd

public class TerrainManager {
    private var terrainState : TerrainState!
    
    var kern_computeControlPoints : MTLFunction!
    var ps_computeControlPoints : MTLComputePipelineState!
    
    var device : MTLDevice!
    var library : MTLLibrary!
    
    var triangleTableBuffer : MTLBuffer!
    var edgeCornersBuffer : MTLBuffer!
    
    var updateBuffers = true
    
    init(device: MTLDevice, library: MTLLibrary, inflightChunksCount: Int) {
        self.device = device
        self.library = library
        self.terrainState = TerrainState(device : device, inflightChunksCount : inflightChunksCount)
        buildComputePipeline()
        setUpLookupTables()
    }
    
    func buildComputePipeline() {
        kern_computeControlPoints = library.makeFunction(name: "kern_computeTriangleControlPoints")
        do { try ps_computeControlPoints = device.makeComputePipelineState(function: kern_computeControlPoints) }
        catch { fatalError("compute control points computePipelineState failed") }
    }

    func updateTerrain() {

    }
    
    func setUpLookupTables() {
        triangleTableBuffer = device.makeBuffer(bytes: TRIANGLES, length: MemoryLayout<Int32>.stride * 15 * 256, options: [])
        edgeCornersBuffer = device.makeBuffer(bytes: CORNER_POSITIONS, length: MemoryLayout<float3>.stride * 24, options: [])
    }
    
    func generateTerrain(commandBuffer : MTLCommandBuffer?, camera : Camera) {
        if !updateBuffers { return }
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let chunkDimension = self.terrainState.chunkDimension
        
        var chunks = [vector_float3]()
        let numChunks = self.terrainState.computeChunksToRender(chunks: &chunks, eye: vector_float3(0.0), count: self.terrainState.inflightChunksCount, camera: camera)
    
        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
        computeCommandEncoder?.setBuffer(triangleTableBuffer, offset: 0, index: 2)
        let threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
        for i in 0..<numChunks {
            var pos = chunks[i]
            print(pos.x, pos.y, pos.z)
        }
        for i in 0..<numChunks {
            let startPos: [vector_float4] = [float4(chunks[i].x, chunks[i].y, chunks[i].z, 1.0)]
            let buffer = self.terrainState.chunk(at: i).terrainBuffer
            let tessBuffer = self.terrainState.chunk(at: i).tessellationFactorBuffer
            computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float4>.size, index: 0)
            computeCommandEncoder?.setBuffer(buffer, offset: 0, index: 1)
            computeCommandEncoder?.setBuffer(tessBuffer, offset: 0, index: 3)
            computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        computeCommandEncoder?.endEncoding()
    }
    
    func drawTerrain(_ commandEncoder : MTLRenderCommandEncoder?, tessellationBuffer: MTLBuffer!) {
        let chunkDimension = self.terrainState.chunkDimension
        commandEncoder?.setVertexBuffer(triangleTableBuffer, offset: 0, index: 2)
        commandEncoder?.setVertexBuffer(edgeCornersBuffer, offset: 0, index: 3)
        for i in 0..<self.terrainState.inflightChunksCount {
            let buffer = self.terrainState.chunk(at: i).terrainBuffer
            let tessBuffer = self.terrainState.chunk(at: i).tessellationFactorBuffer
            commandEncoder?.setVertexBuffer(buffer, offset: 0, index: 0)
            commandEncoder?.setTessellationFactorBuffer(tessBuffer, offset: 0, instanceStride: 0)
            commandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: chunkDimension * chunkDimension * chunkDimension * 5, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        }
    }
    
    func toggleFreeze() {
        updateBuffers = !updateBuffers
    }
}
