//
//  TessellationShaders.metal
//  MiniMinecraft
//
//  Created by William Ho on 1/27/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
#include "terrain_header.metal"
#include "data_types.metal"
using namespace metal;

// Vertex-to-Fragment struct
struct FunctionOutIn {
    float4 position [[position]];
    float3 normal [[attribute(1)]];
    half4  color [[flat]];
};

// Uniform variables
struct Uniforms{
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
};

// Triangle compute kernel
kernel void tessellation_kernel_triangle(constant float& edge_factor [[ buffer(0) ]],
                                         constant float& inside_factor [[ buffer(1) ]],
                                         device MTLTriangleTessellationFactorsHalf* factors [[ buffer(2) ]],
                                         uint pid [[ thread_position_in_grid ]])
{
    // Simple passthrough operation
    if (pid % 2 == 0) {
        factors[pid].edgeTessellationFactor[0] = 0.f;
        factors[pid].edgeTessellationFactor[1] = 0.f;
        factors[pid].edgeTessellationFactor[2] = 0.f;
        factors[pid].insideTessellationFactor = 0.f;
        return;
    }
    factors[pid].edgeTessellationFactor[0] = edge_factor;
    factors[pid].edgeTessellationFactor[1] = edge_factor;
    factors[pid].edgeTessellationFactor[2] = edge_factor;
    factors[pid].insideTessellationFactor = inside_factor;
}

// Quad compute kernel
//kernel void tessellation_kernel_quad(constant float& edge_factor                    [[ buffer(0) ]],
//                                     constant float& inside_factor                  [[ buffer(1) ]],
//                                     device MTLQuadTessellationFactorsHalf* factors [[ buffer(2) ]],
//                                     //device ControlPoint* control_points [[ buffer(3) ]],
//                                     uint pid                                       [[ thread_position_in_grid ]])
//{
//    // Simple passthrough operation
//    // More sophisticated compute kernels might determine the tessellation factors based on the state of the scene (e.g. camera distance)
////    if ((pid+4) % 6 != 0) {
////        factors[pid].edgeTessellationFactor[0] = 0.f;
////        factors[pid].edgeTessellationFactor[1] = 0.f;
////        factors[pid].edgeTessellationFactor[2] = 0.f;
////        factors[pid].insideTessellationFactor[0] = 0.f;
////        factors[pid].insideTessellationFactor[1] = 0.f;
////        return;
////    }
//    factors[pid].edgeTessellationFactor[0] = edge_factor;
//    factors[pid].edgeTessellationFactor[1] = edge_factor;
//    factors[pid].edgeTessellationFactor[2] = edge_factor;
//    factors[pid].edgeTessellationFactor[3] = edge_factor;
//    factors[pid].insideTessellationFactor[0] = inside_factor;
//    factors[pid].insideTessellationFactor[1] = inside_factor;
//}

// Triangle post-tessellation vertex function
[[patch(triangle, 1)]]
vertex FunctionOutIn tessellation_vertex_triangle(PatchIn patchIn                           [[ stage_in ]],
                                                  constant Uniforms &uniforms               [[ buffer(1) ]],
                                                  constant int *triangle_lookup_table       [[ buffer(2) ]],
                                                  constant float3 *corner_positions         [[ buffer(3) ]],
                                                  float3 patch_coord                        [[ position_in_patch ]],
                                                  uint vid                                  [[ patch_id ]])
{
    // Barycentric coordinates
    float u = patch_coord.x;
    float v = patch_coord.y;
    float w = patch_coord.z;
    
    //camera matrices
    float4x4 modViewProjMatrix = uniforms.viewProjectionMatrix * uniforms.modelMatrix;
    
    ControlPoint cp = patchIn.control_points[0];
    FunctionOutIn vertexOut;
    
    int firstVertexId = (int) cp.position.a; // Index in lookup table of first vertex Id
    float LOD = cp.weights.a;
    
    int edge0 = triangle_lookup_table[firstVertexId];
    int edge1 = triangle_lookup_table[firstVertexId+1];
    int edge2 = triangle_lookup_table[firstVertexId+2];
    
    // Convert 3 vertex edges to vertex positions
    // TODO: Revise hard-coded 0.5f interpolation
    half4 myColor;
    myColor.w = 1.0;
    float3 c0 = corner_positions[2*edge0] * LOD + cp.position.xyz;
    float3 c1 = corner_positions[2*edge0+1] * LOD + cp.position.xyz;
    myColor.x = (half) cp.weights.x;
    myColor.y = (half) cp.weights.y;
    myColor.z = (half) cp.weights.z;
    float3 v0 = c0 + cp.weights.x * (c1 - c0);
    
    c0 = corner_positions[2*edge1] * LOD + cp.position.xyz;
    c1 = corner_positions[2*edge1+1] * LOD + cp.position.xyz;
    float3 v1 = c0 + cp.weights.y * (c1 - c0);
    
    c0 = corner_positions[2*edge2] * LOD + cp.position.xyz;
    c1 = corner_positions[2*edge2+1] * LOD + cp.position.xyz;
    float3 v2 = c0 + cp.weights.z * (c1 - c0);
    
    
    // Interpolate between the 3 vertex positions to define current vertex position at it's pre-transformed position
    float3 preTransformPosition = (u * v2 + v * v1 + w * v0);
    
    // Output
    float3 normal = normalize(cross(v0 - v1, v2 - v1));
    vertexOut.position = modViewProjMatrix * float4(preTransformPosition, 1.0);
//    vertexOut.color = half4(u + 0.5, v + 0.5, 1.0-(v + 1.0), 1.0);

    vertexOut.color = myColor;
    vertexOut.normal = normal;
    return vertexOut;
}

// Quad post-tessellation vertex function
//[[patch(quad, 1)]]
//vertex FunctionOutIn tessellation_vertex_quad(PatchIn patchIn [[stage_in]],
//                                              constant Uniforms &uniforms [[buffer(1)]],
//                                              constant float3 *corners[[buffer(2)]],
//                                              float2 patch_coord [[ position_in_patch ]],
//                                              uint vid [[ patch_id ]])
//{
//    // Parameter coordinates
//    float u = patch_coord.x - 0.5;
//    float v = patch_coord.y - 0.5;
//
//    //camera matrices
//    float4x4 modMatrix = uniforms.modelMatrix;
//    float4x4 viewProjection = uniforms.viewProjectionMatrix;
//
//    float4 controlPoint = patchIn.control_points[0].position;
//    FunctionOutIn vertexOut;
//
//    float myFloat = controlPoint.a;
//    int cornerIdx = (int) myFloat;
//    if(cornerIdx < 0) {
//        vertexOut.position = float4(0.0f);
//        return vertexOut;
//    }
//
//    cornerIdx *= 2;
//
//    float3 offset = cross(corners[cornerIdx], corners[cornerIdx+1]);
//    if ((cornerIdx / 2) % 2 != 0) offset = -offset;
//
//    // Linear interpolation
//    float3 preTransformPosition = controlPoint.xyz + u * corners[cornerIdx] + v * corners[cornerIdx + 1] + 0.5f * offset;
//
//    // Output
//    vertexOut.position = viewProjection * modMatrix * float4(preTransformPosition, 1.0);
//    vertexOut.color = half4(1.0, 1.0, 1.0, 1.0);
//    vertexOut.normal = cross(corners[cornerIdx], corners[cornerIdx + 1]);
//    return vertexOut;
//}

// Common fragment function
fragment half4 tessellation_fragment(FunctionOutIn fragmentIn [[stage_in]])
{
    float lambertTerm = max(min(dot(fragmentIn.normal, normalize(float3(1.f, 1.f, 1.f))), 1.f), 0.2f);
    return lambertTerm * fragmentIn.color;
}
