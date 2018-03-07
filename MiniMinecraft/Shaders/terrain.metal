//
//  terrain.metal
//  MiniMinecraft
//
//  Created by William Ho on 2/7/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include "terrain_header.metal"

using namespace metal;

uint8_t inSinWeightedTerrain(thread float3 pos) {
    float heightx = (sin((pos.x / 4.0f) * M_PI)) * 2.0f + 8.0f;
    float heightz = (sin((pos.z / 4.0f) * M_PI)) * 2.0f + 8.0f;
    float height = min(heightx, heightz);
    return (pos.y < height) ? 1 : 0;
}

uint8_t inCheckeredTerrain(thread float3 pos) {
    int result = int(pos.x) % 2 + int(pos.y) % 2 + int(pos.z) % 2;
    return (result > 0) ? 0 : 1;
}

uint8_t inSphereTerrain(thread float3 pos) {
    float radius = 2.5f;
    float3 center = float3((floor(pos.x / 8.0f) + 0.5) * 8.0f,
                           (floor(pos.y / 8.0f) + 0.5) * 8.0f,
                           (floor(pos.z / 8.0f) + 0.5) * 8.0f);
    return (length(pos - center) < radius) ? 1 : 0;
}

