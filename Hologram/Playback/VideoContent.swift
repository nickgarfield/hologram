//
//  VideoContent.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/21/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import SpriteKit
import AVFoundation

class VideoContent: SKScene {
    
    // MARK: - Private properties
    
    private let player: AVPlayer
    
    // MARK: - Initialization
    
    init(videoURL: URL, size: CGSize) {
        // let videoURL = Bundle.main.url(forResource: filename, withExtension: nil)!
        player = AVPlayer(url: videoURL)
        
        super.init(size: size)
        
        backgroundColor = .clear
        scaleMode = .aspectFit
        
        let videoSpriteNode = SKVideoNode(avPlayer: player)
        videoSpriteNode.position = CGPoint(x: size.width/2, y: size.height/2)
        videoSpriteNode.size = size
        videoSpriteNode.yScale = -1
        videoSpriteNode.play()
        addChild(videoSpriteNode)
        
        NotificationCenter
            .default
            .addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                         object: player.currentItem,
                         queue: .main)
            {
                [unowned player] _ in
                player.seek(to: CMTime.zero)
                player.play()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
