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

struct TerrainChunk {
    var startPosition : vector_float3!
    var terrainBuffer : MTLBuffer!

    func distance(camera : Camera) -> Float {
        return 0.0
    }
}



public class TerrainManager {
    private var chunks : [TerrainChunk]
    let chunkDimension = 16
    var inflightChunksCount : Int
    
    var kern_computeControlPoints : MTLFunction!
    var ps_computeControlPoints : MTLComputePipelineState!
    
    var device : MTLDevice!
    var library : MTLLibrary!
    
    var controlPointsIndicesBuffer : MTLBuffer!
    var voxelValuesBuffer : MTLBuffer!
    
    init(device: MTLDevice, library: MTLLibrary, inflightChunksCount: Int) {
        self.device = device
        self.library = library
        self.inflightChunksCount = inflightChunksCount
        self.chunks = [TerrainChunk]()
        let bufferLength = chunkDimension * chunkDimension * chunkDimension * 6 * 4; //chunk dimensions * floats4 per voxel
        for _ in 0...inflightChunksCount-1 {
            chunks.append(TerrainChunk(
                startPosition: vector_float3(0.0, 0.0, 0.0), //unused so far
                terrainBuffer: device.makeBuffer(length: MemoryLayout<Float32>.stride * bufferLength, options: [])))
        }
        buildComputePipeline()
        setUpLookupTables()
    }
    
    func buildComputePipeline() {
        kern_computeControlPoints = library.makeFunction(name: "kern_computeControlPoints")
        do { try ps_computeControlPoints = device.makeComputePipelineState(function: kern_computeControlPoints) }
        catch { fatalError("compute control points computePipelineState failed") }
    }

    func chunk(at : Int) -> TerrainChunk {
        return chunks[at]
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
    
    func generateTerrain(commandBuffer : MTLCommandBuffer?) {
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        computeCommandEncoder?.setComputePipelineState(ps_computeControlPoints!)
        computeCommandEncoder?.setBuffer(voxelValuesBuffer, offset: 0, index: 2)
        let threadExecutionWidth = ps_computeControlPoints.threadExecutionWidth;
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: ((chunkDimension * chunkDimension * chunkDimension) + threadExecutionWidth - 1) / threadExecutionWidth, height: 1, depth: 1)
        for i in 0..<inflightChunksCount {
            let x =  i / 10
            let z = i % 10
            let startPos: [vector_float3] = [vector_float3(Float(chunkDimension * x), 0.0, -Float(chunkDimension * z))]
            let buffer = self.chunk(at: i).terrainBuffer
            computeCommandEncoder?.setBytes(startPos, length: MemoryLayout<vector_float3>.size, index: 0)
            computeCommandEncoder?.setBuffer(buffer, offset: 0, index: 1)
            computeCommandEncoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        computeCommandEncoder?.endEncoding()
    }
    
    func drawTerrain(_ commandEncoder : MTLRenderCommandEncoder?, tessellationBuffer: MTLBuffer!) {
        commandEncoder?.setVertexBuffer(controlPointsIndicesBuffer, offset: 0, index: 2)
        for i in 0..<inflightChunksCount {
            commandEncoder?.setVertexBuffer(chunks[i].terrainBuffer, offset: 0, index: 0)
            commandEncoder?.setTessellationFactorBuffer(tessellationBuffer, offset: 0, instanceStride: 0)
            commandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: chunkDimension * chunkDimension * chunkDimension * 6, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        }
    }
}
