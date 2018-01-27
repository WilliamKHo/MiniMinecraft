//
//  TessellationShaders.metal
//  MiniMinecraft
//
//  Created by William Ho on 1/27/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Control Point struct
struct ControlPoint {
    float4 position [[attribute(0)]];
};

// Patch struct
struct PatchIn {
    patch_control_point<ControlPoint> control_points;
};

// Vertex-to-Fragment struct
struct FunctionOutIn {
    float4 position [[position]];
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
    factors[pid].edgeTessellationFactor[0] = edge_factor;
    factors[pid].edgeTessellationFactor[1] = edge_factor;
    factors[pid].edgeTessellationFactor[2] = edge_factor;
    factors[pid].insideTessellationFactor = inside_factor;
}

// Quad compute kernel
kernel void tessellation_kernel_quad(constant float& edge_factor [[ buffer(0) ]],
                                     constant float& inside_factor [[ buffer(1) ]],
                                     device MTLQuadTessellationFactorsHalf* factors [[ buffer(2) ]],
                                     uint pid [[ thread_position_in_grid ]])
{
    // Simple passthrough operation
    // More sophisticated compute kernels might determine the tessellation factors based on the state of the scene (e.g. camera distance)
    factors[pid].edgeTessellationFactor[0] = edge_factor;
    factors[pid].edgeTessellationFactor[1] = edge_factor;
    factors[pid].edgeTessellationFactor[2] = edge_factor;
    factors[pid].edgeTessellationFactor[3] = edge_factor;
    factors[pid].insideTessellationFactor[0] = inside_factor;
    factors[pid].insideTessellationFactor[1] = inside_factor;
}

// Triangle post-tessellation vertex function
[[patch(triangle, 3)]]
vertex FunctionOutIn tessellation_vertex_triangle(PatchIn patchIn [[stage_in]],
                                                  constant Uniforms &uniforms [[buffer(1)]],
                                                  float3 patch_coord [[ position_in_patch ]])
{
    // Barycentric coordinates
    float u = patch_coord.x;
    float v = patch_coord.y;
    float w = patch_coord.z;
    
    //camera matrices
    float4x4 modMatrix = uniforms.modelMatrix;
    float4x4 viewProjection = uniforms.viewProjectionMatrix;
    
    // Convert to cartesian coordinates
    float x = u * patchIn.control_points[0].position.x + v * patchIn.control_points[1].position.x + w * patchIn.control_points[2].position.x;
    float y = u * patchIn.control_points[0].position.y + v * patchIn.control_points[1].position.y + w * patchIn.control_points[2].position.y;
    
    // Output
    FunctionOutIn vertexOut;
    vertexOut.position = viewProjection * modMatrix * float4(x, y, 0.0, 1.0);
    vertexOut.color = half4(u, v, w, 1.0);
    return vertexOut;
}

// Quad post-tessellation vertex function
[[patch(quad, 1)]]
vertex FunctionOutIn tessellation_vertex_quad(PatchIn patchIn [[stage_in]],
                                              constant Uniforms &uniforms [[buffer(1)]],
                                              float2 patch_coord [[ position_in_patch ]])
{
    // Parameter coordinates
    float u = patch_coord.x - 1.0;
    float v = patch_coord.y - 1.0;
    
    //camera matrices
    float4x4 modMatrix = uniforms.modelMatrix;
    float4x4 viewProjection = uniforms.viewProjectionMatrix;
    
    // Linear interpolation
//    float2 upper_middle = mix(patchIn.control_points[0].position.xy, patchIn.control_points[1].position.xy, u);
//    float2 lower_middle = mix(patchIn.control_points[2].position.xy, patchIn.control_points[3].position.xy, 1-u);
    float4 preTransformPosition = patchIn.control_points[0].position + float4(u * 2.0, v * 2.0, 0.0, 0.0);
    
    // Output
    FunctionOutIn vertexOut;
    vertexOut.position = viewProjection * modMatrix * preTransformPosition;
    vertexOut.color = half4(u + 1.0, v + 1.0, 1.0-(v + 1.0), 1.0);
    return vertexOut;
}


// Common fragment function
fragment half4 tessellation_fragment(FunctionOutIn fragmentIn [[stage_in]])
{
    return fragmentIn.color;
}
