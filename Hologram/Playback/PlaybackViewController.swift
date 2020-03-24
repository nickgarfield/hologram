//
//  ViewController.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import ARKit
import UIKit
import RealityKit

// Non-relevant, but interesting sources on Metal (possible optimization)
// SOURCE: https://github.com/MetalKit/metal
// SOURCE: https://www.youtube.com/watch?v=GLDYreVv4Ns
// SOURCE: https://developer.apple.com/documentation/metal
// SOURCE: http://metalkit.org/2017/07/29/using-arkit-with-metal.html
// SOURCE: http://metalkit.org/2017/08/31/using-arkit-with-metal-part-2.html
// SOURCE: https://www.invasivecode.com/weblog/metal-video-processing-ios-tvos/

// Relevant sources for demo
// SOURCE: https://stackoverflow.com/questions/42469024/how-do-i-create-a-looping-video-material-in-scenekit-on-ios-in-swift-3
// SOURCE: https://developer.apple.com/documentation/arkit/arcoachingoverlayview
// SOURCE: https://developer.apple.com/documentation/spritekit/sknode/getting_started_with_nodes
// SOURCE: https://stackoverflow.com/questions/46225828/how-do-you-play-a-video-with-alpha-channel-using-avfoundation
// SOURCE: https://github.com/2RKowski/SceneKitTransparentVideo
// SOURCE: https://stackoverflow.com/questions/53256602/arkit-skvideonode-playing-on-render?rq=1
// SOURCE: https://stackoverflow.com/questions/53843525/whats-the-best-way-to-play-video-in-scenekit


class PlaybackViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the SceneKit scene
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.isPlaying = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.addHologramNode()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(
            .personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }

        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration)
        sceneView.session.run(configuration, options: options)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        if let playerItem = notification.object as? AVPlayerItem {
            playerItem.seek(to: .zero, completionHandler: nil)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer,
                  didAdd node: SCNNode,
                  for anchor: ARAnchor) {
        
        print("Did add node :: \(node) for anchor :: \(anchor)")
        
    }
    
    var didAddHologramNode: Bool = false
    
    func addHologramNode() {
        
        let point = sceneView.center
        let hologramNode = self.createHologramNode()
        let hitTestResults = sceneView.hitTest(
            point,
            types: .existingPlaneUsingExtent)
        guard let hitTestResult = hitTestResults.first else {
            sceneView.scene.rootNode.addChildNode(hologramNode)
            return
        }
        
        guard let camera = sceneView.session.currentFrame?.camera else { return }
        guard let ppoint = camera.unprojectPoint(point,
                                                 ontoPlane: hitTestResult.worldTransform,
                                                 orientation: .portrait,
                                                 viewportSize: sceneView.frame.size) else {
                                                    
                                                    print("No ppoint")
                                                    return
        }
        
        let x = ppoint.x
        let y = ppoint.y
        let z = ppoint.z
        
//        let translation = hitTestResult.worldTransform.columns.3
//        let x = translation.x
//        let y = translation.y
//        let z = min(-1, translation.z)
        
        // hitTestResult.distance
        let height: CGFloat = 0.3
        (hologramNode.geometry as? SCNPlane)?.height = height
        (hologramNode.geometry as? SCNPlane)?.width = height * 0.75
        
        hologramNode.position = SCNVector3(x,y,z)
        sceneView.scene.rootNode.addChildNode(hologramNode)
    }
    
    func createHologramNode() -> SCNNode {
        
        // Create SpriteKit scene
        let spriteKitScene = SKScene(size: CGSize(width: sceneView.frame.width,
                                                  height: sceneView.frame.height))
        spriteKitScene.scaleMode = .aspectFit

        // Get video url
        let documentsPath = NSString(string: NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true)[0])
        let hologramPath = NSString(string: documentsPath.appendingPathComponent("hologram"))
        let outputPath = hologramPath.appendingPathComponent("ProcessedTest").appending(".mp4")
        let videoURL = URL(fileURLWithPath: outputPath)

        // Create video material
        let videoContent = VideoContent(videoURL: videoURL,
                                        size: CGSize(width: 480, height: 640))
        let chromaKeyMaterial = ChromaKeyMaterial()
        chromaKeyMaterial.diffuse.contents = videoContent

        // Create SceneKit plane node to display video material
        let height: CGFloat = 0.5
        let planeGeometry = SCNPlane(width: height * 0.75, height: height)
        planeGeometry.materials = [chromaKeyMaterial]
        let hologramNode = SCNNode(geometry: planeGeometry)
        hologramNode.position.z = -1
        
        return hologramNode
    }
    
}
