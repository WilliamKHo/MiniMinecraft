//
//  signed_distance_functions_header.metal
//  MiniMinecraft
//
//  Created by William Ho on 4/5/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float sdTorus(float3 p, float3 c, float r);

float sdSphere(float3 p, float3 c, float r);

