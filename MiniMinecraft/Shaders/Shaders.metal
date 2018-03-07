;//
//  Shaders.metal
//  HelloMetalMacOs
//
//  Created by William Ho on 11/12/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

#define CHUNKDIM 16

#include <metal_stdlib>
#include "terrain_header.metal"
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
};


vertex Vertex vertex_func(constant Vertex *vertices [[buffer(0)]],
                          constant Uniforms &uniforms [[buffer(1)]],
                          uint vid [[vertex_id]]) {
    float4x4 modMatrix = uniforms.modelMatrix;
    float4x4 viewProjection = uniforms.viewProjectionMatrix;
    Vertex in = vertices[vid];
    Vertex out;
    out.position = viewProjection * modMatrix * float4(in.position);
    out.color = in.color;
    return out;
}

fragment float4 fragment_func(Vertex vert [[stage_in]]) {
    return vert.color;
}

// Voxel grid to control points shader
kernel void kern_computeControlPoints(constant float3& startPos [[buffer(0)]],
                                      device float4* voxels [[buffer(1)]],
                                      device float3* cubeMarchTable [[buffer(2)]],
                                      uint pid [[ thread_position_in_grid ]]) {
    if (pid >= CHUNKDIM * CHUNKDIM * CHUNKDIM) return;
    uint voxelId = pid * 6;
    
    uint z = (uint) floor(pid / (float)(CHUNKDIM * CHUNKDIM));
    uint y = (uint) floor((pid - (z * CHUNKDIM * CHUNKDIM)) / (float) CHUNKDIM);
    uint x = pid - y * CHUNKDIM - z * CHUNKDIM * CHUNKDIM;
    
    float3 output = float3(x, y, z) + startPos;
    float valid = 1.0f;
    //if (inSinWeightedTerrain(output) > 0) valid = 0.0f;
    //if (inCheckeredTerrain(output) > 0) valid = 0.0f;
    //if (inSphereTerrain(output) > 0) valid = 0.0f;
    if (inPerlinTerrain(output) > 0) valid = 0.0f;
    uint8_t cubeMarchKey = (valid > 0) ? 8 : 15; // Need to revise face making table
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(1.0f, 0.0f, 0.0f)) * 4);
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(0.0f, 1.0f, 0.0f)) * 2);
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(0.0f, 0.0f, 1.0f)));
    
    float3 voxelValues = cubeMarchTable[cubeMarchKey];
    
    voxels[voxelId] = float4(output, voxelValues.x);
    voxels[voxelId+1] = float4(output, voxelValues.y);
    voxels[voxelId+2] = float4(output, voxelValues.z);
    voxels[voxelId+3] = float4(output, -1.0f);
    voxels[voxelId+4] = float4(output, -1.0f);
    voxels[voxelId+5] = float4(output, -1.0f);
}







