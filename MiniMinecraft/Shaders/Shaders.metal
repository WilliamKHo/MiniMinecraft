;//
//  Shaders.metal
//  HelloMetalMacOs
//
//  Created by William Ho on 11/12/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

#include <metal_stdlib>
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
                                      uint pid [[ thread_position_in_grid ]]) {
    if (pid >= 16 * 16 * 16) return;
    uint voxelId = pid * 6;
    
    uint z = (uint) floor(pid / (16.0f * 16.0f));
    uint y = (uint) floor((pid - (z * 16 * 16)) / 16.0f);
    uint x = pid - y * 16 - z * 16 * 16;
    
    float3 output = float3(x, y, z) + startPos;
    
    voxels[voxelId] = float4(output, 0.0f);
    voxels[voxelId+1] = float4(output, 1.0f);
    voxels[voxelId+2] = float4(output, 2.0f);
    voxels[voxelId+3] = float4(output, 3.0f);
    voxels[voxelId+4] = float4(output, 4.0f);
    voxels[voxelId+5] = float4(output, 5.0f);
}







