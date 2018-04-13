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
}
