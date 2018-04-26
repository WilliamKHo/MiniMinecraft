//
//  signed_distance_functions_header.metal
//  MiniMinecraft
//
//  Created by William Ho on 4/5/18.
//  Copyright © 2018 William Ho. All rights reserved.
//  Adapted from http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
//

#include <metal_stdlib>
using namespace metal;

float sdTorus(float3 p, float3 c, float2 t);

float sdSphere(float3 p, float3 c, float r);

float sdBox(float3 p, float3 c, float3 b);

float sdHexPrism(float3 p, float3 c, float2 h);

float sdEllipsoid(float3 p, float3 c, float3 r);

float unionOp(float a, float b);

float intersectionOp(float a, float b);

float differenceOp(float a, float b);
