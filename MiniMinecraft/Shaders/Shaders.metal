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
kernel kern_computeControlPoints(device float4* voxels,
                                 uint3 tgPid [[ threadgroup_position_in_grid ]],
                                 uint3 tPid [[ thread_position_in_threadgroup ]],
                                 uint tid   [[ trhead_index_in_threadgroup ]]) {
    uint voxelId = tid * 6;
    
    uint3 position = tgPid * 32.0f + tPid;
    
    float3 output = float3(position.x, position.y, position.z);
    
    voxels[voxelId] = float4(output, 0.0f);
    voxels[voxelId] = float4(output, 1.0f);
    voxels[voxelId] = float4(output, 2.0f);
    voxels[voxelId] = float4(output, 3.0f);
    voxels[voxelId] = float4(output, 4.0f);
    voxels[voxelId] = float4(output, 5.0f);
}







