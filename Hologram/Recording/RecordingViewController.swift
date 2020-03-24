//
//  RecordingViewController.swift
//  Hologram
//
//  Created by Nicholas Garfield on 3/20/20.
//  Copyright © 2020 Nicholas Garfield. All rights reserved.
//

import AVKit
import Photos
import UIKit

class RecordingViewController: UIViewController {

    // MARK: - Subviews
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var recordButton: UIButton!
    
    let processingAlert = UIAlertController(
        title: "Generating hologram",
        message: "This may take a moment...",
        preferredStyle: .alert)
    
    
    // MARK: - AV Properties
    var videoCapture = VideoCapture()
    var videoProcessor = VideoProcessor()
    // var videoRecorder = VideoRecorder()
    

    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup camera
        setUpCamera()
        
        // setup record button
        recordButton.addTarget(self,
                               action: #selector(startRecording),
                               for: .touchDown)
        recordButton.addTarget(self,
                               action: #selector(stopRecording),
                               for: [.touchUpInside, .touchUpOutside])
        
//        let documentsPath = NSString(string: NSSearchPathForDirectoriesInDomains(
//        .documentDirectory, .userDomainMask, true)[0])
//        let hologramPath = documentsPath.appendingPathComponent("hologram")
//        if let fileURLs = try? FileManager.default.contentsOfDirectory(
//            at: URL(string: hologramPath)!,
//            includingPropertiesForKeys: nil) {
//
//            for fileURL in fileURLs {
//                try? FileManager.default.removeItem(at: fileURL)
//            }
//            // print("Hologram files :: \(fileURLs)")
//
////            self.videoProcessor(videoProcessor,
////                                didFinishProcessingTo: fileURLs!.last!)
//
//        }
//        if !FileManager.default.fileExists(atPath: hologramPath) {
//            try? FileManager.default.createDirectory(
//                atPath: hologramPath,
//                withIntermediateDirectories: false,
//                attributes: [:])
//            print("Tried to create hologram folder")
//        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.startCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stopCapture()
    }
    
    
    // MARK: - Recording
    @objc func startRecording() {
        videoCapture.startRecording()
    }
    
    @objc func stopRecording() {
        videoCapture.stopRecording()
    }
    
    
    // MARK: - Camera
    func setUpCamera() {
        videoCapture.delegate = self
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.startCapture()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
}

extension RecordingViewController: VideoCaptureDelegate {
    
    func videoCapture(_ capture: VideoCapture,
                      didFinishRecordingTo outputFileURL: URL) {
        
        present(processingAlert,
                animated: true,
                completion: {
        
                    self.videoProcessor.delegate = self
                    self.videoProcessor.setUpModel()
                    self.videoProcessor.processVideo(at: outputFileURL)
                    
        })
    }
    
}

extension RecordingViewController: VideoProcessorDelegate {
    
    func videoProcessor(_ processor: VideoProcessor,
                        didFinishProcessingTo url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            // A generated URL
//            let documentsPath = NSString(string: NSSearchPathForDirectoriesInDomains(
//            .documentDirectory, .userDomainMask, true)[0])
//            let hologramPath = NSString(string: documentsPath.appendingPathComponent("hologram"))
//            let outputPath = hologramPath.appendingPathComponent("ProcessedTest").appending(".mp4")
//            let myURL = URL(fileURLWithPath: outputPath)
            
            self.processingAlert.dismiss(animated: true) {
                self.performSegue(withIdentifier: "ARPreview",
                                  sender: self)
            }
            
            // self.saveVideoToLibrary(videoURL: myURL)
//            let player = AVPlayer(url: myURL)
//            let playerViewController = AVPlayerViewController()
//            playerViewController.player = player
//            self.present(playerViewController, animated: true) {
//                playerViewController.player!.play()
//            }
        }
    }
    
    func saveVideoToLibrary(videoURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { saved, error in

            if let error = error {
                print("Error saving video to librayr: \(error.localizedDescription)")
            }
            if saved {
                print("Video save to library")

            }
        }
    }

    
}
