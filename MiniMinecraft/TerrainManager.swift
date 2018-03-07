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
    
    var controlPointsIndicesBuffer : MTLBuffer!
    var voxelValuesBuffer : MTLBuffer!
    
    var updateBuffers = true
    
    init(device: MTLDevice, library: MTLLibrary, inflightChunksCount: Int) {
        self.device = device
        self.library = library
        self.terrainState = TerrainState(device : device, inflightChunksCount : inflightChunksCount)
        buildComputePipeline()
        setUpLookupTables()
    }
    
    func buildComputePipeline() {
        kern_computeControlPoints = library.makeFunction(name: "kern_computeControlPoints")
        do { try ps_computeControlPoints = device.makeComputePipelineState(function: kern_computeControlPoints) }
        catch { fatalError("compute control points computePipelineState failed") }
    }

    func updateTerrain() {

    }
    
    func setUpLookupTables() {
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
        controlPointsIndicesBuffer = device.makeBuffer(bytes: controlPointIndices, length: MemoryLayout<float3>.stride * 12, options: [])
        
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
        voxelValuesBuffer = device.makeBuffer(bytes: voxelValues, length: MemoryLayout<float3>.stride * 16, options: [])
    }
    
    func generateTerrain(commandBuffer : MTLCommandBuffer?, camera : Camera) {
        if !updateBuffers { return }
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let chunkDimension = self.terrainState.chunkDimension
        
        var chunks = [vector_float3]()
        self.terrainState.computeChunksToRender(chunks: &chunks, eye: vector_float3(0.0), count: self.terrainState.inflightChunksCount, camera: camera)
    
        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
        computeCommandEncoder?.setBuffer(voxelValuesBuffer, offset: 0, index: 2)
        let threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
        for i in 0..<self.terrainState.inflightChunksCount {
            let startPos: [vector_float3] = [chunks[i]]
            let buffer = self.terrainState.chunk(at: i).terrainBuffer
            computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float3>.size, index: 0)
            computeCommandEncoder?.setBuffer(buffer, offset: 0, index: 1)
            computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        computeCommandEncoder?.endEncoding()
    }
    
    func drawTerrain(_ commandEncoder : MTLRenderCommandEncoder?, tessellationBuffer: MTLBuffer!) {
        let chunkDimension = self.terrainState.chunkDimension
        //var chunkList = [vector_float3]()
        commandEncoder?.setVertexBuffer(controlPointsIndicesBuffer, offset: 0, index: 2)
        for i in 0..<self.terrainState.inflightChunksCount {
            commandEncoder?.setVertexBuffer(self.terrainState.chunk(at: i).terrainBuffer, offset: 0, index: 0)
            commandEncoder?.setTessellationFactorBuffer(tessellationBuffer, offset: 0, instanceStride: 0)
            commandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: chunkDimension * chunkDimension * chunkDimension * 6, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        }
    }
    
    func toggleFreeze() {
        updateBuffers = !updateBuffers
    }
}
