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

float sdTorus(float3 p, float3 c, float r) {
    return 0.f;
}

float sdSphere(float3 p, float3 c, float r) {
    return max(min(r - length(p-c), 0.5f), -0.5f);
}


