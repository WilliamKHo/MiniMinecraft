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
    var rendered : Bool!
    
    func distance(camera : Camera) -> Float {
        return 0.0
    }
}

class TerrainState {
    private var chunks : [TerrainChunk]
    public let chunkDimension = 16
    public let lowestUnitDistance : Float = 1.0
    var inflightChunksCount : Int
    
    init(device: MTLDevice, inflightChunksCount: Int) {
        self.inflightChunksCount = inflightChunksCount
        self.chunks = [TerrainChunk]()
        let numVoxels = chunkDimension * chunkDimension * chunkDimension
        let floatsPerVoxel = 40; //5 faces * 8 floats
        let uIntsPerVoxel = 20; //3 faces * 4 tessellation factors
        for _ in 0..<inflightChunksCount {
            chunks.append(TerrainChunk(
                startPosition: vector_float4(0.0, 0.0, 0.0, 0.0), //unused so far
                terrainBuffer: device.makeBuffer(length: MemoryLayout<Float32>.stride * numVoxels * floatsPerVoxel, options: []),
                tessellationFactorBuffer: device.makeBuffer(length: numVoxels * uIntsPerVoxel * MemoryLayout<UInt16>.stride, options: []),
                rendered: false))
        }
    }
    
    func containsChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int4) -> Bool {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] { return true } else { return false }
            } else { return false }
        } else { return false }
    }
    
    func addChunk( chunks : inout [Int32 : [Int32 : [Int32 : Float]]], chunk : simd_int4) {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let _ = yLayer[chunk.z] { chunks[chunk.x]![chunk.y]![chunk.z] = 0.0 //This should also never happen
                } else { chunks[chunk.x]![chunk.y]![chunk.z] = 0.0 }
            } else { chunks[chunk.x]![chunk.y] = [chunk.z : 0.0] }
        } else { chunks[chunk.x] = [chunk.y : [chunk.z : 0.0]] }
    }
    
    func addNeighbors( queue : inout [simd_int4], chunk : simd_int4, traversed : inout [Int32 : [Int32 : [Int32 : Float]]]) {
        // Calculate LOD of current chunk
        let dimensionScale = containingChunkDimensionScale(float3(Float(chunk.x) + lowestUnitDistance / 2.0,
                                                                  Float(chunk.y) + lowestUnitDistance / 2.0,
                                                                  Float(chunk.z) + lowestUnitDistance / 2.0))
        let chunkCenter : float3 = float3(Float(chunk.x) + dimensionScale / 2.0, Float(chunk.y) + dimensionScale / 2.0, Float(chunk.z) + dimensionScale / 2.0)
        let testDistance = dimensionScale / 2.0 + lowestUnitDistance / 2.0
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
    
    func computeContainingChunk( _ pos : float3) -> simd_int4 {
        let dimensionScale = containingChunkDimensionScale(pos)
        var chunkFloatId = floor(pos / dimensionScale) * dimensionScale
        return int4(Int32(chunkFloatId.x), Int32(chunkFloatId.y), Int32(chunkFloatId.z), Int32(dimensionScale))
    }
    
    func addPossibleLowLODNeighbors( testPos : float3, queue : inout [simd_int4], traversed : inout [Int32 : [Int32 : [Int32 : Float]]]) {
        let posXTest = testPos + float3(lowestUnitDistance / 4.0, 0.0, 0.0)
        var pos = computeContainingChunk(posXTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negXTest = testPos - float3(lowestUnitDistance / 4.0, 0.0, 0.0)
        pos = computeContainingChunk(negXTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let posYTest = testPos + float3(0.0, lowestUnitDistance / 4.0, 0.0)
        pos = computeContainingChunk(posYTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negYTest = testPos - float3(0.0, lowestUnitDistance / 4.0, 0.0)
        pos = computeContainingChunk(negYTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let posZTest = testPos + float3(0.0, 0.0, lowestUnitDistance / 4.0)
        pos = computeContainingChunk(posZTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
        
        let negZTest = testPos - float3(0.0, 0.0, lowestUnitDistance / 4.0)
        pos = computeContainingChunk(negZTest)
        if !containsChunk(chunks: &traversed, chunk: pos) {
            queue.append(pos)
            addChunk(chunks: &traversed, chunk: pos)
        }
    }
    
    func chunkIntToWorld(chunkId : simd_int4, camera : Camera) -> float4 {
        let chunkLength = Int32(Float(chunkDimension) / lowestUnitDistance)
        var chunkWorld = float4(Float(chunkId.x * chunkLength), Float(chunkId.y * chunkLength), Float(chunkId.z * chunkLength), Float(chunkId.w))
        chunkWorld += float4(camera.pos.x, camera.pos.y, camera.pos.z, 0.0)
        chunkWorld.x = floorf(chunkWorld.x / Float(chunkLength)) * Float(chunkLength)
        chunkWorld.y = floorf(chunkWorld.y / Float(chunkLength)) * Float(chunkLength)
        chunkWorld.z = floorf(chunkWorld.z / Float(chunkLength)) * Float(chunkLength)
        return chunkWorld
    }
    
    func inCameraView(chunk : simd_int4, camera : Camera, planes : [float4]) -> Bool {
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
                        let corner = chunkWorld + float3(Float(Int32(x) * chunkDim * chunk.w),
                                                         Float(Int32(y) * chunkDim * chunk.w),
                                                         Float(Int32(z) * chunkDim * chunk.w))
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
    
    func distanceToCamera(_ : TerrainChunk, camera: Camera) -> Float {
        return 0.0
    }
    
    // Populates chunks with chunk render data and returns the number of chunks to render
    func computeChunksToRender(eye : vector_float3, count : Int, camera : Camera) -> Int {
        // Queue for traversal and table for recording traversed
        var chunksToRender = 1
        var traversed : [Int32 : [Int32 : [Int32 : Float]]] = [0 : [0 : [0 : 0.0]]] // Chunk currently inside of
        var planes = [float4]()
        camera.extractPlanes(planes: &planes)
        var queue = [simd_int4]()
        var chunkInfoList = [vector_float4]()
        addNeighbors(queue: &queue, chunk: int4(0, 0, 0, 1), traversed: &traversed)
        chunkInfoList.append(chunkIntToWorld(chunkId: int4(0, 0, 0, 1), camera: camera))
        for _ in 1..<count {
            // Dequeue until we see something valid
            var validChunkFound = false
            var chunk : simd_int4
            while !validChunkFound {
                // Add everything we see to traversed
                if queue.isEmpty { break //This should never happen, we're BFSing into an infinite space
                } else {
                    chunk = queue.removeFirst()
                    if inCameraView(chunk : chunk, camera : camera, planes : planes) {
                        addNeighbors(queue: &queue, chunk: chunk, traversed: &traversed)
                        // debug
                        print(chunk.x, chunk.y, chunk.z, chunk.w)
                        chunkInfoList.append(chunkIntToWorld(chunkId: chunk, camera: camera))
                        validChunkFound = true
                        chunksToRender += 1
                    }
                }
            }
        }
        
        self.chunks = self.chunks.sorted(by: { distanceToCamera($0, camera: camera) < distanceToCamera($1, camera: camera) })
        var LRUIndex = self.chunks.count - 1
        for i in 0..<chunkInfoList.count {
            // if not in old chunk list
            var containsChunk = false
            for j in 0..<self.chunks.count {
                if distance_squared(self.chunks[j].startPosition, chunkInfoList[i]) < 0.1 {
                    containsChunk = true
                }
            }
            // kick out one of the chunks
            if !containsChunk {
                self.chunks[LRUIndex].startPosition = chunkInfoList[i]
                self.chunks[LRUIndex].rendered = false
                LRUIndex -= 1
                break
            }
        }
        return chunksToRender
    }
    
    func chunk(at : Int) -> TerrainChunk {
        return chunks[at]
    }
    
    func setChunkRendered(at : Int) {
        chunks[at].rendered = true
    }
}
