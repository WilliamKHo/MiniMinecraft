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
import Cocoa
import Carbon.HIToolbox.Events
import Dispatch


class Camera {
    var fovy: Float
    var aspect: Float
    var farClip: Float
    var nearClip: Float
    var pos: vector_float3
    var forward: vector_float3
    var right: vector_float3
    var up: vector_float3
    var ref: vector_float3
    
    // Internal Matrices
    var view_matrix : float4x4
    var proj_matrix : float4x4
    
    
    // Movement
    var velocity : float3 = float3(0.0, 0.0, 0.0)
    var acceleration : float3 = float3(0.0, 0.0, 0.0)
    var rotVelocity : float3 = float3(0.0, 0.0, 0.0)
    var rotAcceleration : float3 = float3(0.0, 0.0, 0.0)
    
    init(fovy: Float,
         aspect: Float,
         farClip: Float,
         nearClip: Float,
         pos: vector_float3,
         forward: vector_float3,
         right: vector_float3,
         up: vector_float3) {
        self.fovy = fovy
        self.aspect = aspect
        self.farClip = farClip
        self.nearClip = nearClip
        self.pos = pos
        self.forward = forward
        self.right = right
        self.up = up
        self.ref = pos + 10 * forward
        
        self.view_matrix = float4x4(1.0)
        self.proj_matrix = float4x4(1.0)
        recomputeAttributes()
    }
    
    public func recomputeAttributes() {
        self.forward = normalize(ref - pos);
        self.right = normalize(cross(forward, vector_float3(0.0, 1.0, 0.0)));
        self.up = normalize(cross(right, forward));
        
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
        
        view_matrix = orientation * translation
        
        // calculate projection matrix
        let s = 1 / (tanf((fovy / 2) * Float.pi / 180));
        let p = farClip / (farClip - nearClip);
        let q = (-farClip * nearClip) / (farClip - nearClip);
        
        let p0 = float4(s / aspect, 0, 0, 0);
        let p1 = float4(0, s, 0, 0);
        let p2 = float4(0, 0, p, q);
        let p3 = float4(0, 0, 1, 0);
        
        proj_matrix = float4x4(rows: [p0, p1, p2, p3] );
    }
    
    public func computeViewMatrix() -> float4x4 {
        return view_matrix
    }
    
    public func computeProjectionMatrix() -> float4x4 {
        return proj_matrix
    }
    
    public func computeViewProjectionMatrix() -> float4x4 {
        return proj_matrix * view_matrix
    }
    
    func extractPlanes(planes : inout [float4]) {
        let viewProj = computeViewProjectionMatrix()
        
        let row0 = float4(viewProj.columns.0.x,
                          viewProj.columns.1.x,
                          viewProj.columns.2.x,
                          viewProj.columns.3.x)
        let row1 = float4(viewProj.columns.0.y,
                          viewProj.columns.1.y,
                          viewProj.columns.2.y,
                          viewProj.columns.3.y)
        let row2 = float4(viewProj.columns.0.z,
                          viewProj.columns.1.z,
                          viewProj.columns.2.z,
                          viewProj.columns.3.z)
        let row3 = float4(viewProj.columns.0.w,
                          viewProj.columns.1.w,
                          viewProj.columns.2.w,
                          viewProj.columns.3.w)
        
        planes.append(row3 - row0)
        planes.append(row3 + row0)
        planes.append(row3 - row1)
        planes.append(row3 + row1)
        planes.append(row3 - row2)
        planes.append(row3 + row2)
    }
    
    func update() {
        let dt : Float = 1.0 / 60.0
        velocity += dt * acceleration
        if (length(velocity) > 100.0){
            velocity = normalize(velocity) * 100
        }
        if (length(acceleration) < 0.5) {
            velocity *= 0.9
        }
        self.pos += dt * velocity
        self.ref += dt * velocity
        
        if (length(rotVelocity) > 10.0){
            rotVelocity = normalize(rotVelocity) * 10
        }
        if (length(rotVelocity) > 0.5) {
            rotVelocity *= 0.8
        } else if (length(rotVelocity) < 0.5) {
            rotVelocity = float3(0.0, 0.0, 0.0)
        }
        rotVelocity += dt * rotAcceleration
        rotateYaw()
        rotatePitch()
        recomputeAttributes()
    }
    
    func deg2Rad(_ deg : Float) -> Float {
        return deg * Float.pi / 180.0
    }
    
    func rotatePitch() {
        var mat : float4x4 = simd_float4x4(1.0)
        let radians = deg2Rad(rotVelocity.x)
        mat = mat.rotate(radians: radians, self.right.x, self.right.y, self.right.z)
        ref = ref - pos
        var newRef = mat * float4(ref.x, ref.y, ref.z, 1.0)
        ref = float3(newRef.x, newRef.y, newRef.z)
        ref = ref + pos
    }
    
    func rotateYaw() {
        var mat : float4x4 = simd_float4x4(1.0)
        let radians = deg2Rad(rotVelocity.y)
        mat = mat.rotate(radians: radians, 0.0, 1.0, 0.0)
        ref = ref - pos
        var newRef = mat * float4(ref.x, ref.y, ref.z, 1.0)
        ref = float3(newRef.x, newRef.y, newRef.z)
        ref = ref + pos
    }
    
    func keyUpEvent(_ event : NSEvent) {
        guard !event.isARepeat else { return }
        
        switch Int(event.keyCode) {
        case kVK_ANSI_W:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_A:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_S:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_D:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_Q:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case kVK_ANSI_Z:
            acceleration = float3(0.0, 0.0, 0.0)
            
        case 123:
            rotAcceleration = float3(0.0, 0.0, 0.0)
            
        case 124:
            rotAcceleration = float3(0.0, 0.0, 0.0)
            
        case 125:
            rotAcceleration = float3(0.0, 0.0, 0.0)
            
        case 126:
            rotAcceleration = float3(0.0, 0.0, 0.0)
            
        default:
            break;
        }
    }
    
    func keyDownEvent(_ event : NSEvent) {
//        guard !event.isARepeat else { return }
        
        switch Int(event.keyCode) {
        case kVK_ANSI_W:
            acceleration += 250 * self.forward
            
        case kVK_ANSI_A:
            acceleration -= 150 * self.right
            
        case kVK_ANSI_S:
            acceleration -= 250 * self.forward
            
        case kVK_ANSI_D:
            acceleration += 150 * self.right
            
        case kVK_ANSI_Q:
            acceleration += 150 * self.up
        
        case kVK_ANSI_Z:
            acceleration -= 150 * self.up
            
        case 123:
            rotAcceleration.y = 50
            
        case 124:
            rotAcceleration.y = -50
            
        case 125:
            rotAcceleration.x = 50
        
        case 126:
            rotAcceleration.x = -50
            
        default:
            break;
        }
    }
    
}

