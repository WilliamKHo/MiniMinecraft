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
    var tessellationFactorBuffer: MTLBuffer!
    
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
        let numVoxels = chunkDimension * chunkDimension * chunkDimension
        let floatsPerVoxel = 12; //3 faces * 4 floats
        let uIntsPerVoxel = 18; //3 faces * 6 tessellation factors
        for _ in 0..<inflightChunksCount {
            chunks.append(TerrainChunk(
                startPosition: vector_float3(0.0, 0.0, 0.0), //unused so far
                terrainBuffer: device.makeBuffer(length: MemoryLayout<Float32>.stride * numVoxels * floatsPerVoxel, options: []),
                tessellationFactorBuffer: device.makeBuffer(length: numVoxels * uIntsPerVoxel * MemoryLayout<UInt16>.stride, options: [])))
        }
    }
    
    func containsChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int3) -> Bool {
//        if let xLayer = chunks[chunk.x] {
//            if let yLayer = xLayer[chunk.y] {
//                if let _ = yLayer[chunk.z] { return true } else { return false }
//            } else { return false }
//        } else { return false }
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
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    if !(x == 0 && y == 0 && z == 0) {
                        let pos = simd_int3(chunk.x+Int32(x), chunk.y+Int32(y), chunk.z+Int32(z))
                        if !containsChunk(chunks: &traversed, chunk: pos) {
                            queue.append(pos)
                            addChunk(chunks: &traversed, chunk: pos)
                        }
                    }
                }
            }
        }
    }
    
    func chunkIntToWorld(chunkId : int3, camera : Camera) -> float3 {
        let chunkDim = Int32(chunkDimension)
        var chunkWorld = float3(Float(chunkId.x * chunkDim), Float(chunkId.y * chunkDim), Float(chunkId.z * chunkDim))
        chunkWorld += camera.pos
        chunkWorld.x = floorf(chunkWorld.x / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.y = floorf(chunkWorld.y / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.z = floorf(chunkWorld.z / Float(chunkDimension)) * Float(chunkDimension)
        return chunkWorld
    }
    
    func inCameraView(chunk : simd_int3, camera : Camera, planes : [float4]) -> Bool {
        let chunkDim = Int32(chunkDimension)
        var chunkWorld = float3(Float(chunk.x * chunkDim), Float(chunk.y * chunkDim), Float(chunk.z * chunkDim))
        chunkWorld += camera.pos
        chunkWorld.x = floorf(chunkWorld.x / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.y = floorf(chunkWorld.y / Float(chunkDimension)) * Float(chunkDimension)
        chunkWorld.z = floorf(chunkWorld.z / Float(chunkDimension)) * Float(chunkDimension)
        for plane in planes {
            var possible = false
            for x in 0...1 {
                for y in 0...1 {
                    for z in 0...1 {
                        let corner = chunkWorld + float3(Float(Int32(x) * chunkDim),
                                                         Float(Int32(y) * chunkDim),
                                                         Float(Int32(z) * chunkDim))
                        if pointPlaneDistance(plane: plane, point: corner) > 0.0 {
                            possible = true
                        }
                    }
                }
            }
            if !possible { return false }
        }
        return true
//        let chunkVector = normalize(chunkWorld - camera.pos)
//        if abs(dot(chunkVector, camera.forward)) > 0.7 { return true } else { return false }
    }
    
    func computeChunksToRender( chunks : inout [vector_float3], eye : vector_float3, count : Int, camera : Camera) -> Int {
        // Queue for traversal and table for recording traversed
        var chunksToRender = 1
        var traversed : [Int32 : [Int32 : [Int32 : Float]]] = [0 : [0 : [0 : 0.0]]] // Chunk currently inside of
        var planes = [float4]()
        camera.extractPlanes(planes: &planes)
        var queue = [simd_int3]()
        addNeighbors(queue: &queue, chunk: int3(0, 0, 0), traversed: &traversed)
        chunks.append(chunkIntToWorld(chunkId: int3(0, 0, 0), camera: camera))
        for _ in 0..<count-1 {
            // Dequeue until we see something valid
            var validChunkFound = false
            var chunk : simd_int3
            while !validChunkFound {
                // Add everything we see to traversed
                if queue.isEmpty { break //This should never happen, we're BFSing into an infinite space
                } else {
                    chunk = queue.removeFirst()
                    if inCameraView(chunk : chunk, camera : camera, planes : planes) &&
                        (chunk.x * chunk.x + chunk.y * chunk.y + chunk.z * chunk.z < 36){
                        addNeighbors(queue: &queue, chunk: chunk, traversed: &traversed)
                        chunks.append(chunkIntToWorld(chunkId: chunk, camera: camera))
                        validChunkFound = true
                        chunksToRender += 1
                    }
                }
            }
        }
        return chunksToRender
    }
    
    func chunk(at : Int) -> TerrainChunk {
        return chunks[at]
    }
}
