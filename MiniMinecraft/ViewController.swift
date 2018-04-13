//
//  ViewController.swift
//  MiniMinecraft
//
//  Created by William Ho on 1/14/18.
//  Copyright © 2018 William Ho. All rights reserved.
//

import Metal
import MetalKit

class ViewController: PlatformViewController {
    

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
    
//    override func becomeFirstResponder() -> Bool {
//        return false
//    }
//
//    override func keyDown(with event: NSEvent) {
//        switch Int(event.keyCode) {
//            case ASKI_
//        }
//    }

}

