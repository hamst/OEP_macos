//
//  ViewController.swift
//  OEP_macos
//
//  Created by Vadim Voloshanov on 3/10/21.
//  Copyright © 2021 Vadim Voloshanov. All rights reserved.
//

import AppKit
import AVFoundation
import Cocoa
import VideoToolbox

class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var imageView: NSImageView!

    private var oep: BNBOffscreenEffectPlayer?
    private var session = AVCaptureSession()
    private var input: AVCaptureDeviceInput?
    private let output = AVCaptureVideoDataOutput()
    private var videoLayer: AVSampleBufferDisplayLayer?
    private var videoInfo: CMVideoFormatDescription?
    private var error: NSError?
    private let outputVideoOrientation: AVCaptureVideoOrientation = .landscapeRight
    private let cameraPosition: AVCaptureDevice.Position = .front
    private let cameraPreset: AVCaptureSession.Preset = .hd1280x720
    private let renderWidth: UInt = 1280
    private let renderHeight: UInt = 720
    private var effectLoaded = false
    private let token = <<#place your token here#>>
    
    override func viewDidLoad() {
        super.viewDidLoad()
        effectPlayerInit()
        loadEffect(effectPath: "effects/test_BG")
        setUpCamera()
        view.wantsLayer = true
    }
    
    override func viewDidLayout() {
        if videoLayer == nil {
            videoLayer = AVSampleBufferDisplayLayer()
            videoLayer?.videoGravity = .resizeAspectFill
            view.layer!.addSublayer(videoLayer!)
        }
        //TODO: Would be nice to put layer resize in View
        videoLayer!.frame = view.layer!.bounds
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    private func effectPlayerInit() {
        oep = BNBOffscreenEffectPlayer.init(width: renderWidth, height: renderHeight, manualAudio: false, token: token as String)
    }

    private func loadEffect(effectPath: String) {
        oep?.loadEffect(effectPath)
        effectLoaded = true
    }
    
    private func unloadEffect(effectPath: String) {
        oep?.unloadEffect()
        effectLoaded = false
    }

    private func setUpCamera() {
        session.beginConfiguration()
        session.sessionPreset = cameraPreset

        guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: AVMediaType.video,
                position: cameraPosition) else { return }
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        guard let input = self.input else { return }
        
        if error == nil && session.canAddInput(input) {
            session.addInput(input)
        }
        
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] as [String : Any]
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        session.addOutput(output)

        if let captureConnection = output.connection(with: .video) {
            captureConnection.videoOrientation = outputVideoOrientation
        }

        session.commitConfiguration()
        session.startRunning()
    }
    
    private func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer?, atTime outputTime: CMTime ) {
        guard let pixelBuffer = pixelBuffer else { return }
        guard let videoLayer = videoLayer else { return }

        if videoInfo != nil && !CMVideoFormatDescriptionMatchesImageBuffer(videoInfo!, pixelBuffer) {
            videoInfo = nil
        }

        if (videoInfo == nil) {
            CMVideoFormatDescriptionCreateForImageBuffer(nil, pixelBuffer, &videoInfo)
        }
        
        guard let videoInfo = videoInfo else { return }
        
        var sampleTimingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: outputTime, decodeTimeStamp: kCMTimeInvalid)
        var sampleBuffer: CMSampleBuffer?
        
        CMSampleBufferCreateForImageBuffer(nil, pixelBuffer, true, nil, nil, videoInfo, &sampleTimingInfo, &sampleBuffer)
        
        guard let buffer = sampleBuffer, videoLayer.isReadyForMoreMediaData else {
            return
        }
        
        videoLayer.enqueue(buffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentationTime = sampleBuffer.presentationTimeStamp

        if (self.effectLoaded) {
            CVPixelBufferLockBaseAddress(imageBuffer, [])
            oep?.processImage(imageBuffer, completion: {(resPixelBuffer) in
                CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                self.renderPixelBuffer(resPixelBuffer, atTime: presentationTime)
            })
        }
        else {
            renderPixelBuffer(imageBuffer, atTime: presentationTime)
        }
    }
}

