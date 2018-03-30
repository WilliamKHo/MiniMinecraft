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
    var startPosition : vector_float4!
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
        let floatsPerVoxel = 20; //3 faces * 4 floats
        let uIntsPerVoxel = 20; //3 faces * 4 tessellation factors
        for _ in 0..<inflightChunksCount {
            chunks.append(TerrainChunk(
                startPosition: vector_float4(0.0, 0.0, 0.0, 0.0), //unused so far
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
        // Assume that the given chunk is already of the form ((0, pow2), (0, pow2))
        // everytime we add neighbors, we're going up a LOD?
        // Calculate the LOD,
        // In each dimension, you can calculate if you are jumping to a lower, same, or higher level of detail.
        // Knowing this information, it is trivial to compute where the neighbor lies
        
        // Calculate LOD of current chunk
        let dimensionScale = containingChunkDimensionScale(float3(Float(chunk.x) + 0.5, Float(chunk.y) + 0.5, Float(chunk.z) + 0.5))
        let chunkCenter : float3 = float3(Float(chunk.x) + dimensionScale / 2.0, Float(chunk.y) + dimensionScale / 2.0, Float(chunk.z) + dimensionScale / 2.0)
        let testDistance = dimensionScale / 2.0 + 0.5
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    if !(x == 0 && y == 0 && z == 0) {
                        let testPos : float3 = chunkCenter + float3(Float(x) * testDistance, Float(y) * testDistance, Float(z) * testDistance)
                        let testPosDimensionScale = containingChunkDimensionScale(testPos)
                        if testPosDimensionScale < dimensionScale {
                            addPossibleLowLODNeighbors(testPos: testPos, queue: &queue, traversed: &traversed)
                        } else {
                            let pos = computeContainingChunk(testPos)
                            if !containsChunk(chunks: &traversed, chunk: pos) {
                                queue.append(pos)
                                addChunk(chunks: &traversed, chunk: pos)
                            }
                        }
                        
                    }
                }
            }
        }
    }
    
    func containingChunkDimensionScale( _ chunkFloatId : float3) -> Float {
        let absFloatId : float3 = abs(chunkFloatId)
        let LOD = fmaxf(floorf(fmaxf(fmaxf(absFloatId.x, absFloatId.y), absFloatId.z)), 1.0)
        return powf(2.0, floorf(log2(LOD)))
    }
    
    func computeContainingChunk( _ pos : float3) -> simd_int3 {
        let dimensionScale = containingChunkDimensionScale(pos)
        var chunkFloatId = floor(pos / dimensionScale) * dimensionScale
        return int3(Int32(chunkFloatId.x), Int32(chunkFloatId.y), Int32(chunkFloatId.z))
    }
    
    func addPossibleLowLODNeighbors( testPos : float3, queue : inout [simd_int3], traversed : inout [Int32 : [Int32 : [Int32 : Float]]]) {
        let posXTest = testPos + float3(0.25, 0.0, 0.0)
        var pos = computeContainingChunk(posXTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negXTest = testPos - float3(0.25, 0.0, 0.0)
        pos = computeContainingChunk(negXTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let posYTest = testPos + float3(0.0, 0.25, 0.0)
        pos = computeContainingChunk(posYTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negYTest = testPos - float3(0.0, 0.25, 0.0)
        pos = computeContainingChunk(negYTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let posZTest = testPos + float3(0.0, 0.0, 0.25)
        pos = computeContainingChunk(posZTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negZTest = testPos - float3(0.0, 0.0, 0.25)
        pos = computeContainingChunk(negZTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
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
