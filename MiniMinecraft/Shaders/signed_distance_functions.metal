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

float sdBox(float3 p, float3 c, float3 b) {
    float3 d = abs(p - c) - b;
    return min(max(d.x,max(d.y,d.z)),0.f) + length(max(d,0.0));
}

float sdHexPrism(float3 p, float3 c, float2 h) {
    float3 q = abs(p - c);
    return max(q.z-h.y,max((q.x*0.866025f+q.y*0.5f),q.y)-h.x);
}

float sdEllipsoid(float3 p, float3 c, float3 r) {
    return (length( (p - c) /r ) - 1.f) * min(min(r.x,r.y),r.z);
}


