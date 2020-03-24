//
//  VideoRecord.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import AVFoundation
import Foundation
import Vision

// Source: https://developer.apple.com/machine-learning/models/
// Source: https://github.com/motlabs/awesome-ml-demos-with-ios#Image-Segmentation
// Source: https://github.com/tucan9389/ImageSegmentation-CoreML

public class VideoProcessor: NSObject {
    
    // MARK: - Other
    var delegate: VideoProcessorDelegate?
    
    
    // MARK: - Vision Properties
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?

    // DeepLabV3(iOS12+), DeepLabV3FP16(iOS12+), DeepLabV3Int8LUT(iOS12+)
    let segmentationModel = DeepLabV3FP16()
    
    
    // MARK: - Video Reader
    var reader: AVAssetReader?
    var readerOutput: AVAssetReaderTrackOutput?
    var currentSample: CMSampleBuffer?
    var currentPixelBuffer: CVPixelBuffer?
    
    
    // MARK: - Video Generator
    var videoGenerator: VideoGenerator?

    
    // MARK: - API
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: segmentationModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel,
                                      completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            
            fatalError()
        }
    }
    
    var processedFrames: Int = 0
    func processVideo(at url: URL) {   
        let asset = AVURLAsset(url: url)
        reader = try? AVAssetReader(asset: asset)
        guard reader != nil else { return }
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let settings = [kCVPixelBufferPixelFormatTypeKey as String :
            Int(kCVPixelFormatType_32BGRA)]
        readerOutput = AVAssetReaderTrackOutput(track: track,
                                                outputSettings: settings)
        guard readerOutput != nil else { return }
        reader!.add(readerOutput!)
        reader!.startReading()
        
        videoGenerator = VideoGenerator(size: track.naturalSize)
        
        print("Processing video at :: \(url.absoluteString)")
        
        processedFrames = 0
        processNextFrame()
    }
    
    private func processNextFrame() {
        guard reader != nil else { return }
        guard readerOutput != nil else { return }
        guard reader!.status == .reading else { return }
        guard let sampleBuffer = readerOutput!.copyNextSampleBuffer() else {
            videoGenerator?.finish { url in
                self.delegate?.videoProcessor(self,
                                              didFinishProcessingTo: url)
            }
            return
        }
        currentSample = sampleBuffer
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentPixelBuffer = pixelBuffer
        
        if processedFrames == 0 {
            let t = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoGenerator?.start(time: t)
        }
        
        predict(with: pixelBuffer)
    }
    
}


protocol VideoProcessorDelegate {
    func videoProcessor(_ processor: VideoProcessor, didFinishProcessingTo url: URL)
}


// MARK: - Inference
extension VideoProcessor {
    
    func predict(with pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            options: [:])
        try? handler.perform([request])
    }
   
    // Post-processing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        guard currentPixelBuffer != nil else { return }
        guard currentSample != nil else { return }
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let segmentationMap = observations.first?.featureValue.multiArrayValue {
            let segMap = SegmentationResultMLMultiArray(mlMultiArray: segmentationMap)

            // Generate new pixel buffer with green-screen background
            let segMapWidth = segMap.segmentationMapWidthSize
            let segMapHeight = segMap.segmentationMapHeightSize
            let outputPixelBuffer = currentPixelBuffer!
            CVPixelBufferLockBaseAddress(outputPixelBuffer,
                                         CVPixelBufferLockFlags(rawValue: 0))
            let width = CVPixelBufferGetWidth(outputPixelBuffer)
            let height = CVPixelBufferGetHeight(outputPixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(outputPixelBuffer)
            guard let baseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) else { return }
            let colRatio = Double(width) / Double(segMapWidth)
            let rowRatio = Double(height) / Double(segMapHeight)
            // print("[SegMap \(processedFrames)] \(segMap.mlMultiArray)")
            for row in 0..<height {
                var pixel = baseAddress + row * bytesPerRow
                for col in 0..<width {
                    let segMapRow = Int(round(Double(row) / rowRatio))
                    let segMapCol = Int(round(Double(col) / colRatio))
                    let segValue = segMap[segMapRow, segMapCol]
                    if segValue != 15 { // == 0 {
                        let blue = pixel
                        blue.storeBytes(of: 0, as: UInt8.self)
                        
                        let green = pixel + 1
                        green.storeBytes(of: 255, as: UInt8.self)

                        let red = pixel + 2
                        red.storeBytes(of: 0, as: UInt8.self)
                        
                        let alpha = pixel + 3
                        alpha.storeBytes(of: 255, as: UInt8.self)
                    } 
                    pixel += 4
                }
            }
            CVPixelBufferUnlockBaseAddress(outputPixelBuffer,
                                           CVPixelBufferLockFlags(rawValue: 0))
            
            // Save generated output as new video
            let t = CMSampleBufferGetPresentationTimeStamp(currentSample!)
            videoGenerator?.append(pixelBuffer: outputPixelBuffer,
                                   presentationTime: t)
            
            print("Processed frame \(processedFrames)")
            processedFrames += 1
            
            processNextFrame()
        }
    }
    
}
