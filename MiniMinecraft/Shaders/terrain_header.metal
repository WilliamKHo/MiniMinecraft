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

float inSinWeightedTerrain(thread float3 pos);

uint8_t inCheckeredTerrain(thread float3 pos);

float inSphereTerrain(thread float3 pos);

float inPerlin3DTerrain(thread float3 pos);

float inPerlin2DTerrain(thread float3 pos);

float inFrameTerrain(thread float3 pos);

float inSinPerlinTerrain(thread float3 pos);

uint8_t inPerlinPlanetTerrain(thread float3 pos);

float inMarble2DTerrain(thread float3 pos);

float inMarblePerlinTerrain(thread float3 pos);
