//
//  ViewController.swift
//  3DFR True Depth
//
//  Created by vasek on 2/27/23.
//


import UIKit
import Accelerate
import AVFoundation
import Photos

class ViewController: UIViewController, AVCaptureDataOutputSynchronizerDelegate {
    
    @IBOutlet weak var image_view: UIImageView!
    
    var displayType = "video"
    let videoDataOutput = AVCaptureVideoDataOutput()
    let depthDataOutput = AVCaptureDepthDataOutput()
    var videoDeviceInput: AVCaptureDeviceInput!
    var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    var depthPixelBuffer: CVPixelBuffer?
    
    var depthFrame: CVPixelBuffer?
    var videoFrame: CVPixelBuffer?
    var imageData: Data?
    let session = AVCaptureSession()
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
    private let dataOutputQueue = DispatchQueue(label: "com.cameraDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
            
        let defaultVideoDevice: AVCaptureDevice? = videoDeviceDiscoverySession.devices.first
        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        depthDataOutput.alwaysDiscardsLateDepthData = true
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            let videoConnection = videoDataOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = true
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
                connection.videoOrientation = .portrait
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            print("Could not add depth data output to the session")
            session.commitConfiguration()
            return
        }
        
        // Search for highest resolution with half-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        let filtered = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })
        
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            session.commitConfiguration()
            return
        }
        
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        session.commitConfiguration()
        
        self.session.startRunning()
        
    }
    
    
    @IBAction func capture_point_cloud(_ sender: Any) {
        
        
//        var output = [String]()
//        for i in stride(from: 480, to: 1, by: -1.0) {
//            for j in stride(from: 375, to: 1, by: -1.0) {
//
//                //if((CVPixelBufferGetBaseAddress(depthPixelBuffer!)) != nil) {
//                    // scale
//                assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer!))
//                CVPixelBufferLockBaseAddress(depthPixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
//
//                    let scale = CGFloat(CVPixelBufferGetWidth(depthPixelBuffer!)) / CGFloat(CVPixelBufferGetWidth(videoFrame!))
//
//                    let depthPoint = CGPoint(x: CGFloat(CVPixelBufferGetWidth(depthPixelBuffer!)) - 1.0 - i * scale, y: j * scale)
//
////                    assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer!))
////                    CVPixelBufferLockBaseAddress(depthPixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
//
//
//                    let rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer!)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthPixelBuffer!)
//                    // swift does not have an Float16 data type. Use UInt16 instead, and then translate
//                    var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
//                    var f32Pixel = Float(0.0)
//
//                    CVPixelBufferUnlockBaseAddress(depthPixelBuffer!, CVPixelBufferLockFlags(rawValue: 1))
//
//                    withUnsafeMutablePointer(to: &f16Pixel) { f16RawPointer in
//                        withUnsafeMutablePointer(to: &f32Pixel) { f32RawPointer in
//                            var src = vImage_Buffer(data: f16RawPointer, height: 1, width: 1, rowBytes: 2)
//                            var dst = vImage_Buffer(data: f32RawPointer, height: 1, width: 1, rowBytes: 4)
//                            vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
//                        }
//                    }
//
//
//
//                    // Convert the depth frame format to cm
//                    //let depthString = String(format: "%.2f cm", f32Pixel * 100)
//                    //                    print(texturePoint.x, texturePoint.y)
//                    //            print(depthPoint.x, depthPoint.y)
//                    //                    print(depthString)
//
//                    let yRatio = Float(i / 640)
//                    let xRatio = Float(j / 480)
//                    //            let realZ = getDepth(from: depthPixelBuffer!, atXRatio: xRatio, atYRatio: yRatio)
//                    let realX = (xRatio * 3019.0 - 1505.961) * f32Pixel * 100 / 2748.359
//                    let realY = (yRatio * 4032.0 - 2023.0803) * f32Pixel * 100 / 2748.359
//                    if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN || (f32Pixel * 100) < 130) {
//                        output.append(String(realX) + " " + String(realY) + " " + String(f32Pixel * 100))
//                    }
//                //}
//                // Update the label
//                //            DispatchQueue.main.async {
//                //                self.touchDepth.textColor = UIColor.white
//                //                self.touchDepth.text = depthString
//                //                self.touchDepth.sizeToFit()
//                //            }
//            }
//        }
//
////            print(output)
//        let fileName = "point_cloud.xyz"
//        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
//        let joineds = output.joined(separator: "\n")
//        do {
//            try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
//        } catch let e {
//            print(e)
//        }
//
//        let activityViewController = UIActivityViewController(activityItems: [url] , applicationActivities: nil)
//
//        DispatchQueue.main.async {
//
//            self.present(activityViewController, animated: true, completion: nil)
//        }
//
//        PHPhotoLibrary.shared().performChanges({
//                let options = PHAssetResourceCreationOptions()
//                let creationRequest = PHAssetCreationRequest.forAsset()
//            creationRequest.addResource(with: .photo, data: self.imageData!, options: options)
//            }, completionHandler: { success, error in
//                if !success {
//                    print("Couldn't save the photo to your photo library: \(String(describing: error))")
//                }
//            })
//
//
//    }
        var output = [String]()
        for i in stride(from: 1, to: 640, by: 1.0) {
            for j in stride(from: 1, to: 480, by: 1.0) {
                
                //if((CVPixelBufferGetBaseAddress(depthPixelBuffer!)) != nil) {
                    // scale
                let f32Pixel = testDepth(depth: depthPixelBuffer!, video: videoFrame!, i: i, j: j)
                    
                    
                    
                    // Convert the depth frame format to cm
                    //let depthString = String(format: "%.2f cm", f32Pixel * 100)
                    //                    print(texturePoint.x, texturePoint.y)
                    //            print(depthPoint.x, depthPoint.y)
                    //                    print(depthString)
                    
                    let yRatio = Float(i / 640)
                    let xRatio = Float(j / 480)
                    //            let realZ = getDepth(from: depthPixelBuffer!, atXRatio: xRatio, atYRatio: yRatio)
                    let realX = (xRatio * 3019.0 - 1505.961) * f32Pixel * 100 / 2748.359
                    let realY = (yRatio * 4032.0 - 2023.0803) * f32Pixel * 100 / 2748.359
                    if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN || (f32Pixel * 100) < 130) {
                        output.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100))
                    }
                //}
                // Update the label
                //            DispatchQueue.main.async {
                //                self.touchDepth.textColor = UIColor.white
                //                self.touchDepth.text = depthString
                //                self.touchDepth.sizeToFit()
                //            }
            }
        }

        //print(output)
        let fileName = "point_cloud.xyz"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        let joineds = output.joined(separator: "\n")
        do {
            try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
        } catch let e {
            print(e)
        }

        let activityViewController = UIActivityViewController(activityItems: [url] , applicationActivities: nil)

        DispatchQueue.main.async {

            self.present(activityViewController, animated: true, completion: nil)
        }
        
            
        PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: self.imageData!, options: options)
            }, completionHandler: { success, error in
                if !success {
                    print("Couldn't save the photo to your photo library: \(String(describing: error))")
                }
            })
        
//        let url = NSURLfileURL(withPath:fileName)

        
        
    }
    
    private func testDepth(depth depthPixelBuffer: CVPixelBuffer, video videoFrame: CVPixelBuffer, i i: CGFloat, j j: CGFloat) -> Float{
        
        // OLD CODE WHICH IS WORKING IN TRUEDEPTH
        
//        assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer))
//        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//
//            let scale = CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)) / CGFloat(CVPixelBufferGetWidth(videoFrame))
//
//            let depthPoint = CGPoint(x: CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)) - 1.0 - i * scale, y: j * scale)
//
////                    assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer))
////                    CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//
//
//            let rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthPixelBuffer)
//            // swift does not have an Float16 data type. Use UInt16 instead, and then translate
//            var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
//            var f32Pixel = Float(0.0)
//
//            CVPixelBufferUnlockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 1))
//
//            withUnsafeMutablePointer(to: &f16Pixel) { f16RawPointer in
//                withUnsafeMutablePointer(to: &f32Pixel) { f32RawPointer in
//                    var src = vImage_Buffer(data: f16RawPointer, height: 1, width: 1, rowBytes: 2)
//                    var dst = vImage_Buffer(data: f32RawPointer, height: 1, width: 1, rowBytes: 4)
//                    vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
//                }
//            }
//        return f32Pixel
        
        assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer))
        CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
            let scale = CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)) / CGFloat(CVPixelBufferGetWidth(videoFrame))
            
//            let depthPoint = CGPoint(x: CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)) - 1.0 - i * scale, y: j * scale)
        let depthPoint = CGPoint(x: i, y: j)
//        print(CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)) - 1.0)
//            print(scale)
//            print(depthPoint)
//                    assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer))
//                    CVPixelBufferLockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            
            let rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer)! + Int(depthPoint.x) * CVPixelBufferGetBytesPerRow(depthPixelBuffer)
            // swift does not have an Float16 data type. Use UInt16 instead, and then translate
            var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.y)]
            var f32Pixel = Float(0.0)
            
            CVPixelBufferUnlockBaseAddress(depthPixelBuffer, CVPixelBufferLockFlags(rawValue: 1))
            
            withUnsafeMutablePointer(to: &f16Pixel) { f16RawPointer in
                withUnsafeMutablePointer(to: &f32Pixel) { f32RawPointer in
                    var src = vImage_Buffer(data: f16RawPointer, height: 1, width: 1, rowBytes: 2)
                    var dst = vImage_Buffer(data: f32RawPointer, height: 1, width: 1, rowBytes: 4)
                    vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
                }
            }
        return f32Pixel
    }
    
    

    @IBAction func switch_view(_ sender: Any) {
        if displayType == "video" {
            displayType = "depth"
        } else if displayType == "depth" {
            displayType = "video"
        }
        print(displayType)
    }

    
    
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedDepthData: AVCaptureSynchronizedDepthData =
            synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData, let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
            synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        // fixed value
        let intrinsicMartix = syncedDepthData.depthData.cameraCalibrationData?.intrinsicMatrix
        let extrinsicMatrix =
            syncedDepthData.depthData.cameraCalibrationData?
            .extrinsicMatrix
        let refenceDimension = syncedDepthData.depthData.cameraCalibrationData?.intrinsicMatrixReferenceDimensions
        
        
//        self.camFx = intrinsicMartix![0][0]
//        self.camFy = intrinsicMartix![1][1]
//        self.camOx = intrinsicMartix![0][2]
//        self.camOy = intrinsicMartix![1][2]
//        self.refWidth = Float(refenceDimension!.width)
//        self.refHeight = Float(refenceDimension!.height)
//
//        self.inmat = intrinsicMartix!
//        self.exmat = extrinsicMatrix!
        
        //print(extrinsicMatrix!)
        var displayPixelBuffer:CVPixelBuffer?
        self.depthPixelBuffer = syncedDepthData.depthData.depthDataMap
        
        self.depthFrame = syncedDepthData.depthData.depthDataMap
        self.videoFrame = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer)
        
        if displayType == "video" {
            displayPixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer)
        }else if displayType == "depth"{
            displayPixelBuffer = syncedDepthData.depthData.depthDataMap
        }

        let image = CIImage(cvPixelBuffer: displayPixelBuffer!)
        let displayImage = UIImage(ciImage: image)
        
        let context = CIContext()
        self.imageData = context.jpegRepresentation(of: image,
                                                    colorSpace: image.colorSpace!,
                                                    options: [:])!
        DispatchQueue.main.async {
            self.image_view.image = displayImage
        }
    }


}


