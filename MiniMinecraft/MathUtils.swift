//
//  MathUtils.swift
//  MiniMinecraft
//
//  Created by William Ho on 3/6/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import simd

// plane : float 4 containing 4 coefficients for plane computation
// point : location in space
func pointPlaneDistance(plane : float4, point : float3) -> Float {
    var normal = float3(plane.x, plane.y, plane.z)
    let distance = plane.w / length(normal)
    normal = normalize(normal)
    let p0 = -normal * distance
    let pointVector = point - p0
    return dot(normal, pointVector)
}
