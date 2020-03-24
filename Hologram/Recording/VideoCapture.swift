//
//  VideoCapture.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo

// SOURCE: https://stackoverflow.com/questions/10356061/avcapturesession-record-video-with-audio

public class VideoCapture: NSObject {
    
    // MARK: - Properties
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: VideoCaptureDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureMovieFileOutput()
    
    var outputURL: URL {
        let documentsPath = NSString(string: NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true)[0])
        let hologramPath = NSString(string: documentsPath.appendingPathComponent("hologram"))
        let outputPath = hologramPath.appendingPathComponent("Test").appending(".mp4")
        let outputURL = URL(fileURLWithPath: outputPath)
        return outputURL
    }
    
    
    // MARK: - API
    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      completion: @escaping (Bool) -> Void) {
        self.setUpCaptureSession(sessionPreset: sessionPreset,
                                 completion: { success in
            completion(success)
        })
    }
    
    
    // MARK: - API
    
    public func startCapture() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    public func stopCapture() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    public func startRecording() {
        print("Start recording")
        videoOutput.startRecording(to: outputURL,
                                   recordingDelegate: self)
    }
    
    public func stopRecording() {
        print("Stop recording")
        videoOutput.stopRecording()
    }
    
    
    // MARK: - Helpers
    func setUpCaptureSession(sessionPreset: AVCaptureSession.Preset,
                             completion: @escaping (_ success: Bool) -> Void) {
        
        // Remove existing files at output URL
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Configure capture session
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
                
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .front) else {
                
            print("Error: no video devices available")
            return
        }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Link video to preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer

        // And audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else { return }
        guard let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return
        }
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        // Add output
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        // Commit
        captureSession.commitConfiguration()
        let success = true
        completion(success)
    }
    
    

}

public protocol VideoCaptureDelegate: class {
    func videoCapture(_ capture: VideoCapture,
                      didFinishRecordingTo outputFileURL: URL)
}


extension VideoCapture: AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(_ output: AVCaptureFileOutput,
                             didStartRecordingTo fileURL: URL,
                             from connections: [AVCaptureConnection]) {
        
        print("Did start recording")
        
    }

    
    public func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        
        print("Did finish recording to :: \(outputFileURL.absoluteString)")
        
        guard error == nil else {
            print("Error :: \(error?.localizedDescription ?? "")"); return }
        
        delegate?.videoCapture(self, didFinishRecordingTo: outputFileURL)
    }

    
}
