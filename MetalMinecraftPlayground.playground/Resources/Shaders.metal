//
//  Shaders.metal
//  HelloMetalMacOs
//
//  Created by William Ho on 11/12/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

#include <metal_stdlib>
//#include "./DataTypes.h"
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

kernel void kern_buildVertexBuffer(device Vertex *vertices[[buffer(0)]],
                              const uint position [[thread_position_in_grid]])
{
    
}

// Quad compute kernel
kernel void kern_tessellation_quad(constant float& edge_factor [[ buffer(0) ]],
                                     constant float& inside_factor [[ buffer(1) ]],
                                     device MTLQuadTessellationFactorsHalf* factors [[ buffer(2) ]],
                                     uint pid [[ thread_position_in_grid ]])
{
    // Simple passthrough operation
    factors[pid].edgeTessellationFactor[0] = edge_factor;
    factors[pid].edgeTessellationFactor[1] = edge_factor;
    factors[pid].edgeTessellationFactor[2] = edge_factor;
    factors[pid].insideTessellationFactor[0] = inside_factor;
    factors[pid].insideTessellationFactor[1] = inside_factor;
}



