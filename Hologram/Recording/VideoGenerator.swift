//
//  VideoGenerator.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import AVFoundation
import UIKit

// SOURCE: https://stackoverflow.com/questions/43838089/capture-metal-mtkview-as-movie-in-realtime
// SOURCE: https://developer.apple.com/documentation/avfoundation/avassetwriter

class VideoGenerator: NSObject {

    
    // MARK: - AVAssetWriter
    private var assetWriter: AVAssetWriter!
    private var assetWriterVideoInput: AVAssetWriterInput!
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor!
    private var size: CGSize?
    
    var outputURL: URL {
        let documentsPath = NSString(string: NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true)[0])
        let hologramPath = NSString(string: documentsPath.appendingPathComponent("hologram"))
        let outputPath = hologramPath.appendingPathComponent("ProcessedTest").appending(".mp4")
        let outputURL = URL(fileURLWithPath: outputPath)
        return outputURL
    }
    

    // MARK: - Initialization
    init?(size: CGSize) {
        super.init()
        
        // Remove existing files at output URL
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Create the asset writer
        self.size = size
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL,
                                            fileType: AVFileType.mp4)
        } catch {
            return nil
        }
        let outputSettings: [String: Any] = [ AVVideoCodecKey : AVVideoCodecType.h264,
                                              AVVideoWidthKey : size.height,
                                              AVVideoHeightKey : size.width ]
        guard assetWriter.canApply(outputSettings: outputSettings,
                                 forMediaType: .video) else { return nil }
        
        // Create video input
        assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                                   outputSettings: outputSettings)
        
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        
        // Create pixel buffer input
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : size.height,
            kCVPixelBufferHeightKey as String : size.width ]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterVideoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        if assetWriter.canAdd(assetWriterVideoInput) {
            assetWriter.add(assetWriterVideoInput)
        }
    }

    
    // MARK: - API
    
    func start(time: CMTime) {
        let b = assetWriter.startWriting()
        print("Start writing :: \(b) :: \(time)")
        assetWriter.startSession(atSourceTime: time)
    }
    
    func append(pixelBuffer: CVPixelBuffer,
                presentationTime: CMTime) {

        while !assetWriterVideoInput.isReadyForMoreMediaData {
            print("Waiting..")
        }
        
        print("Appending pixel buffer for time :: \(presentationTime)")
        
        if let rotatedPixelBuffer = rotate90PixelBuffer(pixelBuffer, factor: 3) {
            if !assetWriterPixelBufferInput.append(rotatedPixelBuffer,
                                                   withPresentationTime: presentationTime) {
                print("Error :: \(assetWriter.error?.localizedDescription ?? "")")
            }
        }
    }
    
    func finish(_ completionHandler: @escaping (URL) -> ()) {
        assetWriterVideoInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: {
            completionHandler(self.outputURL)
        })
    }
    
}
