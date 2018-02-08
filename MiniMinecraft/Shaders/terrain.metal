//
//  terrain.metal
//  MiniMinecraft
//
//  Created by William Ho on 2/7/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include "terrain_header.metal"

using namespace metal;

bool inSinWeightedTerrain(thread float3 pos) {
    float heightx = (sin((pos.x / 32.0f) * M_PI)) * 16.0f + 8.0f;
    float heightz = (sin((pos.z / 32.0f) * M_PI)) * 16.0f + 8.0f;
    float height = min(heightx, heightz);
    return (pos.y < height);
}

