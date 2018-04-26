//
//  terrain.metal
//  MiniMinecraft
//
//  Created by William Ho on 2/7/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include "terrain_header.metal"
#include "signed_distance_functions_header.metal"

using namespace metal;

float inSinWeightedTerrain(thread float3 pos) {
    float heightx = (sin((pos.x / 16.f) * M_PI)) * 8.0f + 8.0f;
    float heightz = (sin((pos.z / 16.f) * M_PI)) * 8.0f + 8.0f;
    
//    heightx += (sin((pos.x / 850.f) * M_PI)) * 50.0f;
//    heightz += (sin((pos.z / 740.f) * M_PI)) * 80.0f;
    
    float height = heightx + heightz;
    return max(min(height - pos.y, 0.5f), -0.5f);
}

uint8_t inCheckeredTerrain(thread float3 pos) {
    int result = int(pos.x) % 2 + int(pos.y) % 2 + int(pos.z) % 2;
    return (result > 0) ? 0 : 1;
}

float inSphereTerrain(thread float3 pos) {
    float radius = 2.5f;
    float3 center = float3((floor(pos.x / 16.0f)) * 16.0f + 8.f,
                           (floor(pos.y / 16.0f)) * 16.0f + 8.f,
                           (floor(pos.z / 16.0f)) * 16.0f + 8.f);
    return radius - length(pos - center);
}

float randNumber(thread float3 n) {
    return fract(sin(dot(n, float3(12.9898, -56.31985, 4.1414))) * 43758.5453);
}

float3 randGrad(thread float3 n) {
    float3 result = float3(fract(sin(dot(n, float3(39.140, -56.339, 4.142)))),
                          fract(cos(dot(n, float3(-32.539, -324.325, 89.33)))),
                          fract(sin(dot(n, float3(39.15028, 1.323, -304.35)))));
    result.x -= 0.5f;
    result.y -= 0.5f;
    result.z -= 0.5f;
    result = normalize(result);
    return result;
}

float perlinInterp(thread float v1, thread float v2, thread float t) {
    float weight = 6.0f * t * t * t * t * t
                    - 15.0f * t * t * t * t
                    + 10.0f * t * t * t;
    return v1 + weight * (v2 - v1);
}

float perlin(thread float3 pos) {
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

float inPerlin3DTerrain(thread float3 pos) {
    float3 sample = pos / 64.0f;
    return perlin(sample) - 0.4f;
}

float inFrameTerrain(thread float3 pos) {
    float3 test = (pos + float3(8.f, 8.f, 8.f)) / 16.0f;
    test = float3(floor(test.x) * 16.f, floor(test.y) * 16.f, floor(test.z) * 16.f);
    float sumDist = 0.f;
    sumDist += abs(pos.x - test.x);
    sumDist += abs(pos.y - test.y);
    sumDist += abs(pos.z - test.z);
    return 1.f - sumDist;
}

float inSinPerlinTerrain(thread float3 pos) {
    return inSinWeightedTerrain(pos) - 3 * max(inPerlin3DTerrain(pos), 0.f) ;
}

uint8_t inPerlinPlanetTerrain(thread float3 pos) {
    float3 planet = float3(0.f, -300.f, 0.f);
    float3 planetNormal = normalize(pos - planet);
    float heightx = (sin((planetNormal.x / 4.f) * M_PI)) * 160.0f + 8.0f;
    float heightz = (sin((planetNormal.z / 2.f) * M_PI)) * 300.0f + 8.0f;
    float heighty = (cos((planetNormal.y / 1.5f) * M_PI)) * 200.f + 8.f;
    float height = heightx + heighty + heightz;
    uint8_t inPlanet = (abs(length(pos - float3(0.f, -500.f, 0.f))) < height) ? 1 : 0;
    
    return inPlanet && inPerlin3DTerrain(pos) == 0;
}

float noise(float a, float b, float c) {
    //get fractional part of x and y
    float fractA = fract(a);
    float fractB = fract(b);
    float fractC = fract(c);
    
    //wrap around
    float a1 = floor(a);
    float b1 = floor(b);
    float c1 = floor(c);
    
    //smooth the noise with bilinear interpolation
    float value = 0.0;
    value += fractA     * fractB     * fractC     * randNumber(float3(c1, b1, a1));
    value += fractA     * (1 - fractB) * fractC     * randNumber(float3(c1, b + 1, a1));
    value += (1 - fractA) * fractB     * fractC     * randNumber(float3(c1, b1, a1 + 1));
    value += (1 - fractA) * (1 - fractB) * fractC     * randNumber(float3(c1, b1 + 1, a1 + 1));
    
    value += fractA     * fractB     * (1 - fractC) * randNumber(float3(c1 + 1, b1, a1));
    value += fractA     * (1 - fractB) * (1 - fractC) * randNumber(float3(c1 + 1, b1 + 1, a1));
    value += (1 - fractA) * fractB     * (1 - fractC) * randNumber(float3(c1 + 1, b1, a1 + 1));
    value += (1 - fractA) * (1 - fractB) * (1 - fractC) * randNumber(float3(c1 + 1, b1 + 1, a1 + 1));
    
    return value;
}

float turbulence(float a, float b) {
    float value = 0.0;
    float size = 32.f;
    
    value += noise(a / size, b / size, 1.f / size) * size;
    size /= 2.0;
    value += noise(a / size, b / size, 1.f / size) * size;
    size /= 2.0;
    value += noise(a / size, b / size, 1.f / size) * size;
    size /= 2.0;
    value += noise(a / size, b / size, 1.f / size) * size;
    size /= 2.0;
    value += noise(a / size, b / size, 1.f / size) * size;
    size /= 2.0;
    value += noise(a / size, b / size, 1.f / size) * size;
    
    return(128.0 * value / 32.f);
}

float inMarble2DTerrain(thread float3 pos) {
    
    // layer 1 of marble
    float xPeriod = 50.f;
    float zPeriod = 70.f;
    float turbPower = 25.f;
    float3 sample = float3(pos.x / 64.f, 1.f, pos.z / 64.f);
    float xzValue = pos.x / xPeriod + pos.z / zPeriod + turbPower * perlin(sample);
    float sineValue = 5.f * sin(xzValue);
    
    // layer 2
    xPeriod = 300.f;
    zPeriod = 300.f;
    turbPower = 200.f;
    sample = sample / 64.f;
    xzValue = pos.x / xPeriod + pos.z / zPeriod + turbPower * perlin(sample);
    sineValue += 50.f * sin(xzValue);

    return pos.y - sineValue;
}

float inMarblePerlinTerrain(thread float3 pos) {
    //return inMarble2DTerrain(pos) - 3 * max(inPerlin3DTerrain(pos), 0.f) + 4 * max(sdSphere(pos, float3(10.f, 100.f, 10.f), 40.f), 0.f);
    float3 s = float3(100.f, 200.f, 89.f);
    float3 spheresCenter = float3(floor(pos.x / s.x), floor(pos.y / s.y), floor(pos.z / s.z));
    spheresCenter *= s;
    spheresCenter += 0.5f * s;
    return min(min(sdSphere(pos, spheresCenter, 30.f), sdSphere(pos, spheresCenter + float3(60.f, -20.f, 0.f), 40.f)),max(-inPerlin3DTerrain(pos), inMarble2DTerrain(pos)));
}

float sdfTestScene(thread float3 pos) {
    float3 torusC = float3(-50.f, 0.f, -20.f);
    float2 t = float2(10.f, 3.f);
    
    float3 sphereC = float3(0.f, 0.f, -20.f);
    float r = 10.f;
    
    float3 boxC = float3(50.f, 0.f, -20.f);
    float3 b = float3(5.f, 10.f, 15.f);
    
    float3 hexC = float3(0.f, 50.f, -20.f);
    float2 h = float2(10.f, 5.f);
    
    float3 ellipC = float3(0.f, -50.f, -20.f);
    float3 e = float3(10.f, 8.f, 12.f);
    
    return min(min(min(sdTorus(pos, torusC, t), sdSphere(pos, sphereC, r)),
                   min(sdBox(pos, boxC, b), sdHexPrism(pos, hexC, h))),
               sdEllipsoid(pos, ellipC, e));
}

float csgTestScene(thread float3 pos) {
    float3 torusC = float3(0.f, 0.f, -20.f);
    float2 t = float2(10.f, 5.f);
    
    float3 sphereC = float3(0.f, 0.f, -20.f);
    float r = 10.f;
    
    float3 boxC = float3(0.f, 0.f, -20.f);
    float3 b = float3(5.f, 10.f, 15.f);
    
    float3 hexC = float3(0.f, 50.f, -20.f);
    float2 h = float2(10.f, 5.f);
    
    float3 ellipC = float3(0.f, 50.f, -20.f);
    float3 e = float3(10.f, 8.f, 12.f);
    
    float intersectHE = max(sdEllipsoid(pos, ellipC, e), sdHexPrism(pos, hexC, h));
    
    float intersectSB = max(sdSphere(pos, sphereC, r), sdBox(pos, boxC, b));
    
    float diffSBT = max(-sdTorus(pos, torusC, t), intersectSB);
    
    return min(intersectHE, diffSBT);
}


