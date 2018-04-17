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
    var use : Bool!
}

class TerrainState {
    private var chunks : [TerrainChunk]
    private var LODDistances : [Float]
    public let chunkDimension = 16
    public let lowestUnitDistance : Float = 1.0
    var inflightChunksCount : Int
    
    
    init(device: MTLDevice, inflightChunksCount: Int) {
        self.inflightChunksCount = inflightChunksCount
        self.chunks = [TerrainChunk]()
        self.LODDistances = [Float]()
        LODDistances.append(80.0)
        LODDistances.append(140.0)
        let numVoxels = chunkDimension * chunkDimension * chunkDimension
        let floatsPerVoxel = 40; //5 faces * 8 floats
        let uIntsPerVoxel = 20; //3 faces * 4 tessellation factors
        for _ in 0..<inflightChunksCount {
            chunks.append(TerrainChunk(
                startPosition: vector_float4(0.0, 0.0, 0.0, 0.0), //unused so far
                terrainBuffer: device.makeBuffer(length: MemoryLayout<Float32>.stride * numVoxels * floatsPerVoxel, options: []),
                tessellationFactorBuffer: device.makeBuffer(length: numVoxels * uIntsPerVoxel * MemoryLayout<UInt16>.stride, options: []),
                rendered: false,
                use: false))
        }
    }
    
    func containsChunk( chunks : inout [Int32 : [Int32 : [Int32 : [Int32 :Float]]]], chunk : simd_int4) -> Bool {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let zLayer = yLayer[chunk.z] {
                    if let _ = zLayer[chunk.w] { return true } else { return false }
                } else { return false }
            } else { return false }
        } else { return false }
    }
    
    func addChunk( chunks : inout [Int32 : [Int32 : [Int32 : [Int32 : Float]]]], chunk : simd_int4) {
        if let xLayer = chunks[chunk.x] {
            if let yLayer = xLayer[chunk.y] {
                if let zLayer = yLayer[chunk.z] {
                    if let _ = zLayer[chunk.w] { chunks[chunk.x]![chunk.y]![chunk.z]![chunk.w] = 0.0 //This should also never happen
                    } else { chunks[chunk.x]![chunk.y]![chunk.z]![chunk.w] = 0.0 }
                } else { chunks[chunk.x]![chunk.y]![chunk.z] = [chunk.w : 0.0] }
            } else { chunks[chunk.x]![chunk.y] = [chunk.z : [chunk.w : 0.0]] }
        } else { chunks[chunk.x] = [chunk.y : [chunk.z : [chunk.w : 0.0]]] }
    }
    
    func addNeighbors( queue : inout [simd_int4], chunk : simd_int4, traversed : inout [Int32 : [Int32 : [Int32 : [Int32 : Float]]]]) {
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    if !(x == 0 && y == 0 && z == 0) {
                        let pos = simd_int4(chunk.x + Int32(x) * chunk.w, chunk.y + Int32(y) * chunk.w, chunk.z + Int32(z) * chunk.w, chunk.w)
                        if !containsChunk(chunks: &traversed, chunk: pos) {
                            queue.append(pos)
                            addChunk(chunks: &traversed, chunk: pos)
                        }
                    }
                }
            }
        }
    }
    
    func addChildren( queue : inout [simd_int4], chunk : simd_int4, traversed :inout [Int32 : [Int32 : [Int32 : [Int32 : Float]]]]) {
        if chunk.w == 1 { return }
        let LOD = chunk.w / 2
        for x in 0...1 {
            for y in 0...1 {
                for z in 0...1 {
                    var pos = chunk &+ simd_int4(LOD * Int32(x), LOD * Int32(y), LOD * Int32(z), 0)
                    pos.w = LOD
                    if !containsChunk(chunks: &traversed, chunk: pos) {
                        queue.append(pos)
                        addChunk(chunks: &traversed, chunk: pos)
                    }
                }
            }
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
    }
    
    func isCorrectLOD(chunk : simd_int4) -> Bool {
        if chunk.w == 1 { return true }
        // Identify what the correct LOD is
        let startPos = float3(Float(chunk.x) * Float(chunkDimension), Float(chunk.y) * Float(chunkDimension), Float(chunk.z) * Float(chunkDimension))
        let startPosDistance = startPos.x * startPos.x + startPos.y * startPos.y + startPos.z * startPos.z
        var correctLOD = 1
        var radius1 : Float = 0.0
        var radius2 : Float = 0.0
        for i in 0..<LODDistances.count {
            radius1 = radius2
            radius2 = LODDistances[i] * LODDistances[i]
            if startPosDistance < radius2 {
                break
            }
            correctLOD *= 2
        }
        if correctLOD != chunk.w {
            if correctLOD > chunk.w { return true }
            else { return false }
        }
        for x in 0..<2 {
            for y in 0..<2 {
                for z in 0..<2 {
                    let pos = startPos + float3(Float(x * chunkDimension), Float(y * chunkDimension), Float(z * chunkDimension))
                    let posDistance = pos.x * pos.x + pos.y * pos.y + pos.z * pos.z
                    if startPosDistance > radius2 {
                        if posDistance < radius2 { return false }
                    } else {
                        if posDistance < radius1 || posDistance > radius2 { return false }
                    }
                }
            }
        }
        return true
    }
    
    func distanceToCamera(_ s : vector_float4, camera: Camera) -> Float {
        return distance_squared(float3(s.x, s.y, s.z), camera.pos) + (s.w / 10.0)
    }
    
    // Populates chunks with chunk render data and returns the number of chunks to render
    func computeChunksToRender(eye : vector_float3, count : Int, camera : Camera) -> Int {
        // Queue for traversal and table for recording traversed
        var traversed : [Int32 : [Int32 : [Int32 : [Int32 : Float]]]] = [0 : [0 : [0 : [1 : 0.0]]]] // Chunk currently inside of
        var planes = [float4]()
        camera.extractPlanes(planes: &planes)
        var queue = [simd_int4]()
        var chunkInfoList = [vector_float4]()
        let highestLOD = Int32(powf(2.0, Float(LODDistances.count)))
        addNeighbors(queue: &queue, chunk: int4(0, 0, 0, 1), traversed: &traversed)
        chunkInfoList.append(chunkIntToWorld(chunkId: int4(0, 0, 0, 1), camera: camera))
        queue.append(int4(0, 0, 0, highestLOD))
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
                        // If it's the correct LOD, add it to our chunksToRender
                        if isCorrectLOD(chunk: chunk) {
                            chunkInfoList.append(chunkIntToWorld(chunkId: chunk, camera: camera))
                            validChunkFound = true
                        } else {
                            addChildren(queue: &queue, chunk: chunk, traversed: &traversed)
                        }
                        if chunk.w == highestLOD { addNeighbors(queue: &queue, chunk: chunk, traversed: &traversed) }
                        // If not, add it's children to the queue
                        // debug
                    }
                }
            }
        }
        
        
        // Sort chunks by distance from camera
        self.chunks = self.chunks.sorted(by: { distanceToCamera($0.startPosition, camera: camera) < distanceToCamera($1.startPosition, camera: camera) })
        chunkInfoList = chunkInfoList.sorted(by:{ distanceToCamera($0, camera: camera) < distanceToCamera($1, camera: camera) })
        
        // Set up flags. No new chunks have been found and no old chunks should be reused
        var chunkInfoSeen : [Bool] = Array(repeating : false, count : chunkInfoList.count)
        for i in 0..<self.chunks.count {
            self.chunks[i].use = false
        }
        
        // Sorted list intersection code
        var a = 0; var b = 0
        while (a < self.chunks.count && b < chunkInfoList.count) {
            let dista = distanceToCamera(self.chunks[a].startPosition, camera: camera)
            let distb = distanceToCamera(chunkInfoList[b], camera: camera)
            if dista - distb < -0.01{
                a += 1
            } else if distb - dista  < -0.01{
                b += 1
            } else {
                // Chunks that belong in the intersection of old and new
                // Can be used in the next frame and have been identified as "seen"
                self.chunks[a].use = true
                chunkInfoSeen[b] = true
                a += 1
                b += 1
            }
        }
        
        // We now deal with those new chunks that have not already been generated
        // LP - lowest priority given to farthest chunks
        var LPIndex = self.chunks.count - 1
        var chunksToRender = 0
        for i in 0..<chunkInfoList.count {
            if !chunkInfoSeen[i] {
                chunksToRender += 1
                // Find the last available chunk
                while self.chunks[LPIndex].use {
                    LPIndex -= 1
                    if LPIndex < 0 {
                        break
                    }
                }
                if LPIndex < 0 {
                    print("Error in LP calculation")
                    break
                }
                // Mark this chunk as in use and ready to be rendered
                self.chunks[LPIndex].startPosition = chunkInfoList[i]
                self.chunks[LPIndex].use = true
                self.chunks[LPIndex].rendered = false
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
