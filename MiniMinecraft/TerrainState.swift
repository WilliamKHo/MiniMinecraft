//
//  TerrainState.swift
//  MiniMinecraft
//
//  Created by William Ho on 2/25/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import simd
import Metal

struct TerrainChunk {
    var startPosition : vector_float3!
    var terrainBuffer : MTLBuffer!
    
    func distance(camera : Camera) -> Float {
        return 0.0
    }
}

class TerrainState {
    private var chunks : [TerrainChunk]
    public let chunkDimension = 16
    var inflightChunksCount : Int
    
    init(device: MTLDevice, inflightChunksCount: Int) {
        self.inflightChunksCount = inflightChunksCount
        self.chunks = [TerrainChunk]()
        let bufferLength = chunkDimension * chunkDimension * chunkDimension * 6 * 4; //chunk dimensions * floats4 per voxel
        for _ in 0..<inflightChunksCount {
            chunks.append(TerrainChunk(
                startPosition: vector_float3(0.0, 0.0, 0.0), //unused so far
                terrainBuffer: device.makeBuffer(length: MemoryLayout<Float32>.stride * bufferLength, options: [])))
        }
    }
    
    func containsChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int3) -> Bool {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] { return true } else { return false }
            } else { return false }
        } else { return false }
    }
    
    func addChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int3) {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] { chunks[chunk.x]![chunk.y]![chunk.z] = 0.0 //This should also never happen
                } else { chunks[chunk.x]![chunk.y]![chunk.z] = 0.0 }
            } else { chunks[chunk.x]![chunk.y] = [chunk.z : 0.0] }
        } else { chunks[chunk.x] = [chunk.y : [chunk.z : 0.0]] }
    }
    
    func addNeighbors( queue : inout [simd_int3], chunk : simd_int3, traversed : inout [Int32 : [Int32 : [Int32 : Float]]]) {
        let posX = simd_int3(chunk.x+1, chunk.y, chunk.z)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(posX) }
        
        let posY = simd_int3(chunk.x, chunk.y+1, chunk.z)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(posY) }
        
        let posZ = simd_int3(chunk.x, chunk.y, chunk.z+1)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(posZ) }
        
        let negX = simd_int3(chunk.x-1, chunk.y, chunk.z)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(negX) }
        
        let negY = simd_int3(chunk.x, chunk.y-1, chunk.z)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(negY) }
        
        let negZ = simd_int3(chunk.x, chunk.y, chunk.z-1)
        if !containsChunk(chunks: &traversed, chunk: posX) { queue.append(negZ) }
    }
    
    func inCameraView(chunk : simd_int3, camera : Camera) -> Bool {
        let chunkDim = Int32(chunkDimension)
        var chunkWorld = float3(Float(chunk.x * chunkDim), Float(chunk.y * chunkDim), Float(chunk.z * chunkDim))
        chunkWorld += camera.pos
        chunkWorld.x = floorf(chunkWorld.x / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.y = floorf(chunkWorld.y / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.z = floorf(chunkWorld.z / Float(chunkDimension)) * Float(chunkDimension)
        let chunkVector = normalize(chunkWorld - camera.pos)
        if abs(dot(chunkVector, camera.forward)) > 0.7 { return true } else { return false }
    }
    
    func computeChunksToRender( chunks : inout [vector_float3], eye : vector_float3, count : Int, camera : Camera) {
        // Queue for traversal and table for recording traversed
        var traversed : [Int32 : [Int32 : [Int32 : Float]]] = [0 : [0 : [0 : 0.0]]] // Chunk currently inside of
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
                if queue.isEmpty { break //This should never happen, we're BFSing into an infinite space
                } else {
                    chunk = queue.removeFirst()
                    addChunk(chunks: &traversed, chunk: chunk)
                    if inCameraView(chunk: chunk, camera: camera) {
                        addNeighbors(queue: &queue, chunk: chunk, traversed: &traversed)
                        let chunkDim = Int32(chunkDimension)
                        var chunkWorld = float3(Float(chunk.x * chunkDim), Float(chunk.y * chunkDim), Float(chunk.z * chunkDim))
                        chunkWorld += camera.pos
                        chunkWorld.x = floorf(chunkWorld.x / Float(chunkDimension)) * Float(chunkDimension)
                        chunkWorld.y = floorf(chunkWorld.y / Float(chunkDimension)) * Float(chunkDimension)
                        chunkWorld.z = floorf(chunkWorld.z / Float(chunkDimension)) * Float(chunkDimension)
                        chunks.append(chunkWorld)
                        validChunkFound = true
                    }
                }
            }
        }
    }
    
    func chunk(at : Int) -> TerrainChunk {
        return chunks[at]
    }
}
