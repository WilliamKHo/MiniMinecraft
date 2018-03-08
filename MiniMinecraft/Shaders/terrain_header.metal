//
//  terrain_header.metal
//  MiniMinecraft
//
//  Created by William Ho on 2/7/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define M_PI 3.1415926535f

uint8_t inSinWeightedTerrain(thread float3 pos);

uint8_t inCheckeredTerrain(thread float3 pos);

uint8_t inSphereTerrain(thread float3 pos);

uint8_t inPerlinTerrain(thread float3 pos);

uint8_t inFrameTerrain(thread float3 pos);


