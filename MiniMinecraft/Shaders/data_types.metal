//
//  data_types.metal
//  MiniMinecraft
//
//  Created by William Ho on 4/1/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct ControlPoint {
    float4 position [[attribute(0)]];
    float4 weights  [[attribute(1)]];
};

// Patch struct
struct PatchIn {
    patch_control_point<ControlPoint> control_points;
};

