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
                                      device MTLQuadTessellationFactorsHalf* factors [[ buffer(3) ]],
                                      uint pid [[ thread_position_in_grid ]]) {
    if (pid >= CHUNKDIM * CHUNKDIM * CHUNKDIM) return;
    uint voxelId = pid * 3;
    
    uint z = (uint) floor(pid / (float)(CHUNKDIM * CHUNKDIM));
    uint y = (uint) floor((pid - (z * CHUNKDIM * CHUNKDIM)) / (float) CHUNKDIM);
    uint x = pid - y * CHUNKDIM - z * CHUNKDIM * CHUNKDIM;
    
    float3 output = float3(x, y, z) + startPos;
    float valid = 1.0f;
//    if (inSinWeightedTerrain(output) > 0) valid = 0.0f;
    //if (inCheckeredTerrain(output) > 0) valid = 0.0f;
//    if (inSphereTerrain(output) > 0) valid = 0.0f;
    if (inPerlinTerrain(output) > 0) valid = 0.0f;
//    if (inFrameTerrain(output) > 0) valid = 0.0f;
//    if (inSinPerlinTerrain(output) > 0) valid = 0.0f;

    uint8_t cubeMarchKey = (valid > 0) ? 0 : 15; // Need to revise face making table
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(1.0f, 0.0f, 0.0f)) * 4);
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(0.0f, 1.0f, 0.0f)) * 2);
    cubeMarchKey = cubeMarchKey^(inPerlinTerrain(output + float3(0.0f, 0.0f, 1.0f)));
    
    float3 voxelValues = cubeMarchTable[cubeMarchKey];
    
    voxels[voxelId] = float4(output, voxelValues.x);
    voxels[voxelId+1] = float4(output, voxelValues.y);
    voxels[voxelId+2] = float4(output, voxelValues.z);
    
    // Tessellation
    
    MTLQuadTessellationFactorsHalf factorX = factors[voxelId];
    float xT = ((cubeMarchKey & 4) > 0) ? 1.f : 0.f;
    factorX.edgeTessellationFactor[0] = xT;
    factorX.edgeTessellationFactor[1] = xT;
    factorX.edgeTessellationFactor[2] = xT;
    factorX.edgeTessellationFactor[3] = xT;
    factorX.insideTessellationFactor[0] = xT;
    factorX.insideTessellationFactor[1] = xT;
    factors[voxelId] = factorX;
    
    MTLQuadTessellationFactorsHalf factorY = factors[voxelId + 1];
    float yT = ((cubeMarchKey & 2) > 0) ? 1.f : 0.f;
    factorY.edgeTessellationFactor[0] = yT;
    factorY.edgeTessellationFactor[1] = yT;
    factorY.edgeTessellationFactor[2] = yT;
    factorY.edgeTessellationFactor[3] = yT;
    factorY.insideTessellationFactor[0] = yT;
    factorY.insideTessellationFactor[1] = yT;
    factors[voxelId + 1] = factorY;

    
    MTLQuadTessellationFactorsHalf factorZ = factors[voxelId + 2];
    float zT = ((cubeMarchKey & 1) > 0) ? 1.f : 0.f;
    factorZ.edgeTessellationFactor[0] = zT;
    factorZ.edgeTessellationFactor[1] = zT;
    factorZ.edgeTessellationFactor[2] = zT;
    factorZ.edgeTessellationFactor[3] = zT;
    factorZ.insideTessellationFactor[0] = zT;
    factorZ.insideTessellationFactor[1] = zT;
    factors[voxelId + 2] = factorZ;
}

// Voxel grid to control points shader
kernel void kern_computeTriangleControlPoints(constant float4& startPos [[buffer(0)]],
                                              device float4* control_points [[buffer(1)]],
                                              constant int *triangle_lookup_table [[buffer(2)]],
                                              device MTLTriangleTessellationFactorsHalf* factors [[ buffer(3) ]],
                                              uint pid [[ thread_position_in_grid ]]) {
    if (pid >= CHUNKDIM * CHUNKDIM * CHUNKDIM) return;
    uint voxelId = pid * 5;
    
    uint z = (uint) floor(pid / (float)(CHUNKDIM * CHUNKDIM));
    uint y = (uint) floor((pid - (z * CHUNKDIM * CHUNKDIM)) / (float) CHUNKDIM);
    uint x = pid - y * CHUNKDIM - z * CHUNKDIM * CHUNKDIM;
    
    float scale = startPos.w;
    float3 output = float3(x, y, z) * scale + startPos.xyz;
    //float valid = 1.0f;
    //    if (inSinWeightedTerrain(output) > 0) valid = 0.0f;
    //if (inCheckeredTerrain(output) > 0) valid = 0.0f;
    //    if (inSphereTerrain(output) > 0) valid = 0.0f;
    //if (inPerlinTerrain(output) > 0) valid = 0.0f;
    //    if (inFrameTerrain(output) > 0) valid = 0.0f;
    //    if (inSinPerlinTerrain(output) > 0) valid = 0.0f;
    
    uint8_t caseKey = inSinPerlinTerrain(output);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(0.0f, scale, 0.0f)) * 2);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(0.0f, scale, scale)) * 4);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(0.0f, 0.0f, scale)) * 8);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(scale, 0.0f, 0.0f)) * 16);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(scale, scale, 0.0f)) * 32);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(scale, scale, scale)) * 64);
    caseKey = caseKey^(inSinPerlinTerrain(output + float3(scale, 0.0f, scale)) * 128);
    
    // We now have a caseKey in the interval 0...255
    
    // for 5 possible triangles,
    //       set control_points[triangleId].w to the triangleFirstVertexId
    //       check to see if triangle_lookup_table[triangleFirstVertexId] is greater than -1
    //       set the tessellatinofactors to 1.f or 0.f depending on that
    
    
    int triangleFirstVertexId = 15 * (int) caseKey;
    int triangleId = voxelId;
    scale = log2(scale) / 10.0f;
    
    // Unwrapped loop
    control_points[triangleId] = float4(output, (float) triangleFirstVertexId + scale);
    MTLTriangleTessellationFactorsHalf tessFactors;
    float factor = (triangle_lookup_table[triangleFirstVertexId] < 0) ? 0.f : 1.f;
    tessFactors.edgeTessellationFactor[0] = factor;
    tessFactors.edgeTessellationFactor[1] = factor;
    tessFactors.edgeTessellationFactor[2] = factor;
    tessFactors.insideTessellationFactor = factor;
    factors[triangleId] = tessFactors;
    
    triangleFirstVertexId += 3;
    triangleId += 1;
    control_points[triangleId] = float4(output, (float) triangleFirstVertexId + scale);
    factor = (triangle_lookup_table[triangleFirstVertexId] < 0) ? 0.f : 1.f;
    tessFactors.edgeTessellationFactor[0] = factor;
    tessFactors.edgeTessellationFactor[1] = factor;
    tessFactors.edgeTessellationFactor[2] = factor;
    tessFactors.insideTessellationFactor = factor;
    factors[triangleId] = tessFactors;
    
    triangleFirstVertexId += 3;
    triangleId += 1;
    control_points[triangleId] = float4(output, (float) triangleFirstVertexId + scale);
    factor = (triangle_lookup_table[triangleFirstVertexId] < 0) ? 0.f : 1.f;
    tessFactors.edgeTessellationFactor[0] = factor;
    tessFactors.edgeTessellationFactor[1] = factor;
    tessFactors.edgeTessellationFactor[2] = factor;
    tessFactors.insideTessellationFactor = factor;
    factors[triangleId] = tessFactors;
    
    triangleFirstVertexId += 3;
    triangleId += 1;
    control_points[triangleId] = float4(output, (float) triangleFirstVertexId + scale);
    factor = (triangle_lookup_table[triangleFirstVertexId] < 0) ? 0.f : 1.f;
    tessFactors.edgeTessellationFactor[0] = factor;
    tessFactors.edgeTessellationFactor[1] = factor;
    tessFactors.edgeTessellationFactor[2] = factor;
    tessFactors.insideTessellationFactor = factor;
    factors[triangleId] = tessFactors;
    
    triangleFirstVertexId += 3;
    triangleId += 1;
    control_points[triangleId] = float4(output, (float) triangleFirstVertexId + scale);
    factor = (triangle_lookup_table[triangleFirstVertexId] < 0) ? 0.f : 1.f;
    tessFactors.edgeTessellationFactor[0] = factor;
    tessFactors.edgeTessellationFactor[1] = factor;
    tessFactors.edgeTessellationFactor[2] = factor;
    tessFactors.insideTessellationFactor = factor;
    factors[triangleId] = tessFactors;
}
