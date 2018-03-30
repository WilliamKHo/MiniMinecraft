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
    float heightx = (sin((pos.x / 160.f) * M_PI)) * 15.0f + 8.0f;
    float heightz = (sin((pos.z / 120.f) * M_PI)) * 20.0f + 8.0f;
    
    heightx += (sin((pos.x / 850.f) * M_PI)) * 50.0f;
    heightz += (sin((pos.z / 740.f) * M_PI)) * 80.0f;
    
    float height = heightx + heightz;
    return (pos.y < height) ? 1 : 0;
}

uint8_t inCheckeredTerrain(thread float3 pos) {
    int result = int(pos.x) % 2 + int(pos.y) % 2 + int(pos.z) % 2;
    return (result > 0) ? 0 : 1;
}

uint8_t inSphereTerrain(thread float3 pos) {
    float radius = 2.5f;
    float3 center = float3((floor(pos.x / 16.0f)) * 16.0f + 8.f,
                           (floor(pos.y / 16.0f)) * 16.0f + 8.f,
                           (floor(pos.z / 16.0f)) * 16.0f + 8.f);
    return (length(pos - center) < radius) ? 1 : 0;
}

float3 randGrad(float3 n) {
    float3 result = float3(fract(sin(dot(n, float3(12.9898, -56.31985, 4.1414))) * 43758.5453),
                          fract(cos(dot(n, float3(-32.53920, -324.32515, 89.3203))) * 21044.2185),
                          fract(sin(dot(n, float3(39.9315028, 1.32593, -304.3285))) * 54083.3290));
    result.x -= 0.5f;
    result.y -= 0.5f;
    result.z -= 0.5f;
    result = normalize(result);
    return result;
}

float perlinInterp(float v1, float v2, float t) {
    float weight = 6.0f * t * t * t * t * t
                    - 15.0f * t * t * t * t
                    + 10.0f * t * t * t;
    return v1 + weight * (v2 - v1);
}

float perlin(float3 pos) {
    float3 min = float3(floor(pos.x), floor(pos.y), floor(pos.z));
    float3 grad = randGrad(min);
    float3 dist = pos - min;
    float3 unitLocation = dist;
    
    float w000 = dot(grad, dist);
    
    grad = randGrad(float3(min.x + 1.0f, min.y, min.z));
    dist.x -= 1.0f;
    float w100 = dot(grad, dist);
    
    grad = randGrad(float3(min.x, min.y + 1.0f, min.z));
    dist.x += 1.0f;
    dist.y -= 1.0f;
    float w010 = dot(grad, dist);
    
    grad = randGrad(float3(min.x, min.y, min.z + 1.0f));
    dist.y += 1.0f;
    dist.z -= 1.0f;
    float w001 = dot(grad, dist);
    
    grad = randGrad(float3(min.x + 1.0f, min.y + 1.0f, min.z));
    dist.z += 1.0f;
    dist.x -= 1.0f;
    dist.y -= 1.0f;
    float w110 = dot(grad, dist);
    
    grad = randGrad(float3(min.x, min.y + 1.0f, min.z + 1.0f));
    dist.x += 1.0f;
    dist.z -= 1.0f;
    float w011 = dot(grad, dist);
    
    grad = randGrad(float3(min.x + 1.0f, min.y, min.z + 1.0f));
    dist.x -= 1.0f;
    dist.y += 1.0f;
    float w101 = dot(grad, dist);
    
    grad = randGrad(float3(min.x + 1.0f, min.y + 1.0f, min.z + 1.0f));
    dist.y -= 1.0f;
    float w111 = dot(grad, dist);
    
    float x00 = perlinInterp(w000, w100, unitLocation.x);
    float x01 = perlinInterp(w001, w101, unitLocation.x);
    float x10 = perlinInterp(w010, w110, unitLocation.x);
    float x11 = perlinInterp(w011, w111, unitLocation.x);
    
    float y0 = perlinInterp(x00, x10, unitLocation.y);
    float y1 = perlinInterp(x01, x11, unitLocation.y);

    return (perlinInterp(y0, y1, unitLocation.z) + 1.f) / 2.f;
}

uint8_t inPerlinTerrain(thread float3 pos) {
    float threshold = 0.4f;
    float3 sample = pos / 64.0f;
    return (perlin(sample) < threshold) ? 1 : 0;
}

uint8_t inFrameTerrain(thread float3 pos) {
    float3 test = (pos + float3(8.f, 8.f, 8.f)) / 16.0f;
    test = float3(floor(test.x) * 16.f, floor(test.y) * 16.f, floor(test.z) * 16.f);
    int count = 0;
    count += (abs(pos.x - test.x) < 1.f) ? 1 : 0;
    count += (abs(pos.y - test.y) < 1.f) ? 1 : 0;
    count += (abs(pos.z - test.z) < 1.f) ? 1 : 0;
    return count == 2 ? 1 : 0;
}

uint8_t inSinPerlinTerrain(thread float3 pos) {
    return inSinWeightedTerrain(pos)  == 1 && inPerlinTerrain(pos) == 0;
}

uint8_t inPerlinPlanetTerrain(thread float3 pos) {
    float3 planet = float3(0.f, -300.f, 0.f);
    float3 planetNormal = normalize(pos - planet);
    float heightx = (sin((planetNormal.x / 4.f) * M_PI)) * 160.0f + 8.0f;
    float heightz = (sin((planetNormal.z / 2.f) * M_PI)) * 300.0f + 8.0f;
    float heighty = (cos((planetNormal.y / 1.5f) * M_PI)) * 200.f + 8.f;
    float height = heightx + heighty + heightz;
    uint8_t inPlanet = (abs(length(pos - float3(0.f, -500.f, 0.f))) < height) ? 1 : 0;
    
    return inPlanet && inPerlinTerrain(pos) == 0;
}


