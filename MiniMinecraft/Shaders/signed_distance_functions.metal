//
//  signed_distance_functions.metal
//  MiniMinecraft
//
//  Created by William Ho on 4/5/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
#include "signed_distance_functions_header.metal"
using namespace metal;

float sdTorus(float3 p, float3 c, float2 t) {
    float3 P = p - c;
    float2 q = float2(length(P.xz) - t.x, P.y);
    return length(q) - t.y;
}

float sdSphere(float3 p, float3 c, float r) {
    return length(p-c) - r;
}


