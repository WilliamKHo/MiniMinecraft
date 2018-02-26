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
        var chunkList = [vector_float3]()
        computeChunksToRender( chunks : &chunkList, eye : vector_float3(1.0), count : 300)
        commandEncoder?.setVertexBuffer(controlPointsIndicesBuffer, offset: 0, index: 2)
        for i in 0..<inflightChunksCount {
            commandEncoder?.setVertexBuffer(chunks[i].terrainBuffer, offset: 0, index: 0)
            commandEncoder?.setTessellationFactorBuffer(tessellationBuffer, offset: 0, instanceStride: 0)
            commandEncoder?.drawPatches(numberOfPatchControlPoints: 1, patchStart: 0, patchCount: chunkDimension * chunkDimension * chunkDimension * 6, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)
        }
    }
    
    func containsChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int3) -> Bool {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    func addChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int3) {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] {
                    chunks[chunk.x]![chunk.y]![chunk.z] = 0.0 //This should also never happen
                } else {
                    chunks[chunk.x]![chunk.y]![chunk.z] = 0.0
                }
            } else {
                chunks[chunk.x]![chunk.y] = [chunk.z : 0.0]
            }
        } else {
            chunks[chunk.x] = [chunk.y : [chunk.z : 0.0]]
        }
    }
    
    func addNeighbors( queue : inout [simd_int3], chunk : simd_int3, traversed : inout [Int32 : [Int32 : [Int32 : Float]]]) {
        let posX = simd_int3(chunk.x+1, chunk.y, chunk.z)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(posX)
        }
        
        let posY = simd_int3(chunk.x, chunk.y+1, chunk.z)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(posY)
        }
        
        let posZ = simd_int3(chunk.x, chunk.y, chunk.z+1)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(posZ)
        }
        
        let negX = simd_int3(chunk.x-1, chunk.y, chunk.z)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(negX)
        }
        
        let negY = simd_int3(chunk.x, chunk.y-1, chunk.z)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(negY)
        }
        
        let negZ = simd_int3(chunk.x, chunk.y, chunk.z-1)
        if containsChunk(chunks: &traversed, chunk: posX) {
            queue.append(negZ)
        }
    }
    
    func computeChunksToRender( chunks : inout [vector_float3], eye : vector_float3, count : Int) {
        // Queue for traversal and table for recording traversed
        var traversed : [Int32 : [Int32 : [Int32 : Float]]] = [0 : [0 : [0 : 0.0]]] //Chunk currently inside of
        var queue = [simd_int3]()
        queue.append(simd_int3(1, 0, 0))
        queue.append(simd_int3(-1, 0, 0))
        queue.append(simd_int3(0, 1, 0))
        queue.append(simd_int3(0, -1, 0))
        queue.append(simd_int3(0, 0, 1))
        queue.append(simd_int3(0, 0, -1))
        
        chunks.append(vector_float3(Float(chunkDimension),
                                    Float(chunkDimension),
                                    Float(chunkDimension)))
        for _ in 0..<count-1 {
            // Dequeue until we see something valid
            var validChunkFound = false
            var chunk : simd_int3
            while !validChunkFound {
                // Add everything we see to traversed
                if queue.isEmpty {
                    break //This should never happen, we're BFSing into an infinite space
                } else {
                    chunk = queue.removeFirst()
                    if chunk.x % 2 == 0 { // If valid condition is met
                        validChunkFound = true
                        addNeighbors(queue: &queue, chunk: chunk, traversed: &traversed)
                    }
                    addChunk(chunks: &traversed, chunk: chunk)
                }
            }
            // Once we have something to add, add its non-traversed neighbors to our queue
            chunks.append(vector_float3(Float(chunkDimension),
                                        Float(chunkDimension),
                                        Float(chunkDimension)))
        }
    }
}
