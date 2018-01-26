//
//  Camera.swift
//  ForeflightCodingChallenge
//
//  Created by William Ho on 11/26/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

// Basic perspective projection camera

import Foundation
import simd

class Camera {
    var fov: Float
    var aspect: Float
    var farClip: Float
    var nearClip: Float
    var pos: vector_float4
    var forward: vector_float3
    var right: vector_float3
    var up: vector_float3
    
    init(fov: Float,
         aspect: Float,
         farClip: Float,
         nearClip: Float,
         pos: vector_float4,
         forward: vector_float3,
         right: vector_float3,
         up: vector_float3) {
        self.fov = fov
        self.aspect = aspect
        self.farClip = farClip
        self.nearClip = nearClip
        self.pos = pos
        self.forward = forward
        self.right = right
        self.up = up
    }
    
    public func computeViewProjectionMatrix() -> float4x4 {
        // orientation matrix
        let o0 = float4(right[0], right[1], right[2], 0);
        let o1 = float4(up[0], up[1], up[2], 0);
        let o2 = float4(forward[0], forward[1], forward[2], 0);
        let o3 = float4(0, 0, 0, 1);
        let orientation = float4x4(rows: [o0, o1, o2, o3]);
        
        // translation matrix
        let t0 = float4(1, 0, 0, -pos[0]);
        let t1 = float4(0, 1, 0, -pos[1]);
        let t2 = float4(0, 0, 1, -pos[2]);
        let t3 = float4(0, 0, 0, 1);
        let translation = float4x4(rows: [t0, t1, t2, t3]);
        
        let view = orientation * translation;
        
        // calculate projection matrix
        let s = 1 / (tanf((fov / 2) * Float.pi / 180));
        let p = farClip / (farClip - nearClip);
        let q = (-farClip * nearClip) / (farClip - nearClip);
        
        let p0 = float4(s / aspect, 0, 0, 0);
        let p1 = float4(0, s, 0, 0);
        let p2 = float4(0, 0, p, q);
        let p3 = float4(0, 0, 1, 0);
        
        let projection = float4x4(rows: [p0, p1, p2, p3] );
        
        return projection * view
    }
    
}

