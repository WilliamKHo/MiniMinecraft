//
//  GameViewController.swift
//  Landscape-iOS
//
//  Created by William Ho on 4/11/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Metal
import MetalKit

// Our iOS specific view controller
class GameViewController: UIViewController {

    var metalView: MTKView?
    
    var commandQueue: MTLCommandQueue?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.metalView = self.view as? MetalView
        self.metalView?.device = MTLCreateSystemDefaultDevice()
        
        if(metalView?.device == nil)
        {
            print("Metal Is Not Supported On This Device");
            return;
        }
        
        // Do any additional setup after loading the view.
    }
    @IBAction func rotateLeftDown(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camRotLeft)
    }
    @IBAction func rotateLeftUp(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
    }
    
    @IBAction func rotateRightDown(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camRotRight)
    }
    @IBAction func rotateRightUp(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
    }
    
    @IBAction func rotateUpUp(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
    }
    @IBAction func rotateUpDown(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camRotDown)
    }
    
    
    @IBAction func rotateDownDown(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camRotUp)
    }
    @IBAction func rotateDownUp(_ sender: Any) {
        RenderManager.sharedInstance.inputEvent(InputCode.camDecelerateRot)
    }
}
