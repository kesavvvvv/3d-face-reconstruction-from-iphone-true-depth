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
import FirebaseStorage
import Zip

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

class ViewController: UIViewController, AVCaptureDataOutputSynchronizerDelegate {
    
    @IBOutlet weak var image_view: UIImageView!
    
    @IBOutlet weak var pointcloudName: UITextField!
    
    @IBOutlet weak var realXrealYtoggle: UISwitch!
    
    @IBOutlet weak var depthColorToggle: UISwitch!
    
    @IBOutlet weak var imageToggle: UISwitch!
    
    @IBOutlet weak var nameToggle: UISwitch!
    
    @IBOutlet weak var totalFrameBox: UITextField!
    
    var videoToggle = false
    
    let device = UIDevice.current
    
    @IBAction func videoTrigger(_ sender: Any) {
        if(!videoToggle) {
            videoToggle = true
        } else {
            videoToggle = false
        }
            
    }
    @IBAction func videoEnd(_ sender: Any) {
        videoToggle = true
    }
    var depthFrameBuffer: [CVPixelBuffer] = []
    var videoFrameBuffer: [CVPixelBuffer] = []
    var frameCounter = 0
    var frameBufferEnable = 0
    var displayType = "video"
    let videoDataOutput = AVCaptureVideoDataOutput()
    let depthDataOutput = AVCaptureDepthDataOutput()
    var videoDeviceInput: AVCaptureDeviceInput!
    var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    var depthPixelBuffer: CVPixelBuffer?
    var pixelBuffer: CVPixelBuffer?
    var depthFrame: CVPixelBuffer?
    var videoFrame: CVPixelBuffer?
    var resizedBuffer: CVPixelBuffer?
    var sessionZipFiles = [URL] ()
    var imageData: Data?
    var actualImage: UIImage?
    var inputText: String?
    let session = AVCaptureSession()
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
    private let dataOutputQueue = DispatchQueue(label: "com.cameraDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    @IBAction func TextChanged(_ sender: Any) {
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        nameToggle.isOn = false
        imageToggle.isOn = false
        depthColorToggle.isOn = false
        
        // Do any additional setup after loading the view.
        
        self.hideKeyboardWhenTappedAround()
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
        
        // change this for high quality image
        
//        session.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
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
    
    @IBAction func continuous_point_cloud(_ sender: Any) {
        
        
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
        
        frameBufferEnable = 1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var final_output = [[String]]()
        var counting = 0
        var totalFrames = totalFrameBox.text ?? "10"
        for depthFrame_1 in self.depthFrameBuffer {
            var output = [String]()
            for i in stride(from: 1, to: 640, by: 1.0) {
                for j in stride(from: 1, to: 480, by: 1.0) {
                    var line = String()
                    //if((CVPixelBufferGetBaseAddress(depthPixelBuffer!)) != nil) {
                    // scale
                    
                    let f32Pixel = testDepth(depth: depthFrame_1, video: self.videoFrameBuffer[counting], i: i, j: j)
                    
                    //                let baseAddress = CVPixelBufferGetBaseAddress(videoFrame!)
                    //
                    //                let bytesPerRow = CVPixelBufferGetBytesPerRow(videoFrame!)
                    //                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                    //
                    //                    let index = j*4 + i*Double(bytesPerRow)
                    //                    let b = buffer[Int(index)]
                    //                    let g = buffer[Int(index)+1]
                    //                    let r = buffer[Int(index)+2]
                    
                    
                    //                print(CGFloat(CVPixelBufferGetWidth(resizedBuffer!)))
                    
                    
                    // Convert the depth frame format to cm
                    //let depthString = String(format: "%.2f cm", f32Pixel * 100)
                    //                    print(texturePoint.x, texturePoint.y)
                    //            print(depthPoint.x, depthPoint.y)
                    //                    print(depthString)
                    if(realXrealYtoggle.isOn) {
                        let yRatio = Float(i / 640)
                        let xRatio = Float(j / 480)
                        //            let realZ = getDepth(from: depthPixelBuffer!, atXRatio: xRatio, atYRatio: yRatio)
                        let realX = (xRatio * 3019.0 - 1505.961) * f32Pixel * 100 / 2748.359
                        let realY = (yRatio * 4032.0 - 2023.0803) * f32Pixel * 100 / 2748.359
                        if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN) {
                            line.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100) + " ")
                        }
                    } else {
                        if(!f32Pixel.isNaN) {
                            line.append(String(-f32Pixel * 100) + " ")
                        }
                    }
                    
                    
                    
                    //                if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN || (f32Pixel * 100) < 130) {
                    //                    output.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100) + " " + String(r) + " " + String(g) + " " + String(b))
                    //                }
                    
                    if(depthColorToggle.isOn) {
                        CVPixelBufferLockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                        let baseAddress = CVPixelBufferGetBaseAddress(resizedBuffer!)
                        let int32PerRow = CVPixelBufferGetBytesPerRow(resizedBuffer!)
                        let int32Buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        
                        //                let bytesPerRow = CVPixelBufferGetBytesPerRow(movieFrame)
                        //                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        let index = (j) * 4 + (i) * Double(int32PerRow)
                        let b = int32Buffer[Int(index)]
                        let g = int32Buffer[Int(index)+1]
                        let r = int32Buffer[Int(index)+2]
                        
                        // Get BGRA value for pixel (43, 17)
                        //                let luma = int32Buffer[17 * int32PerRow + 43*4]
                        
                        CVPixelBufferUnlockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                        
                        line.append(String(r) + " " + String(g) + " " + String(b))
                    }
                    
                    output.append(line)
                    
                    //}
                    // Update the label
                    //            DispatchQueue.main.async {
                    //                self.touchDepth.textColor = UIColor.white
                    //                self.touchDepth.text = depthString
                    //                self.touchDepth.sizeToFit()
                    //            }
                }
            }
            final_output.append(output)
            counting += 1
            print("testing " + String(counting))
            
        }
        
        self.depthFrameBuffer.removeAll()
        
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let dateString = df.string(from: date)
        
        // create the actual alert controller view that will be the pop-up
        let alertController = UIAlertController(title: "Point Cloud File Name", message: "name of point cloud", preferredStyle: .alert)

        alertController.addTextField { (textField) in
            // configure the properties of the text field
            textField.placeholder = "Name"
        }

        var inputName: String?
        // add the buttons/actions to the view controller
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(timeElapsed) s.")
            print(String(final_output.count))
            
        var url_arr = [URL]()
            
            //print(output)
            for i in 0...(final_output.count - 1) {
                let fileName = ( inputName ?? "pointcloud" ) + "_frame_" + String(i) + ".xyz"
                
                //        let fileName = "point_cloud_" + dateString + ".xyz"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                let joineds = final_output[i].joined(separator: "\n")
                do {
                    try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
                } catch let e {
                    print(e)
                }
                
                url_arr.append(url)
                
                //        let url = NSURLfileURL(withPath:fileName)
                
                if(self.imageToggle.isOn) {
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: self.imageData!, options: options)
                    }, completionHandler: { success, error in
                        if !success {
                            print("Couldn't save the photo to your photo library: \(String(describing: error))")
                        }
                    })
                }
                
                //            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                //            print("Time elapsed: \(timeElapsed) s.")
                
//                do {
//                    let storageReference = Storage.storage().reference().child(fileName)
//                    let currentUploadTask = storageReference.putFile(from: url) { (storageMetaData, error) in
//                        if let error = error {
//                            print("Upload error: \(error.localizedDescription)")
//                            return
//                        }
//                        
//                        // Show UIAlertController here
//                        print("Image file: \(fileName) is uploaded! View it at Firebase console!")
//                        
//                        storageReference.downloadURL { (url, error) in
//                            if let error = error  {
//                                print("Error on getting download url: \(error.localizedDescription)")
//                                return
//                            }
//                            print("Download url of \(fileName) is \(url!.absoluteString)")
//                        }
//                    }
//                } catch {
//                    print("Error on extracting data from url: \(error.localizedDescription)")
//                }
                
                
            }
        var zipFilePath = URL(string: "")
        
        
        do {
            zipFilePath = try Zip.quickZipFiles(url_arr, fileName: "archive")
//            print("Zipping " + fileName)
        }
        catch {
            print("Unable to Zip file")
        }
        let activityViewController = UIActivityViewController(activityItems: [zipFilePath!] , applicationActivities: nil)

        DispatchQueue.main.async {

            self.present(activityViewController, animated: true, completion: nil)
        }
        
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
        let startTime = CFAbsoluteTimeGetCurrent()
        var output = [String]()
        for i in stride(from: 1, to: 640, by: 1.0) {
            for j in stride(from: 1, to: 480, by: 1.0) {
                var line = String()
                //if((CVPixelBufferGetBaseAddress(depthPixelBuffer!)) != nil) {
                    // scale
                let f32Pixel = testDepth(depth: depthPixelBuffer!, video: videoFrame!, i: i, j: j)
                    
//                let baseAddress = CVPixelBufferGetBaseAddress(videoFrame!)
//                    
//                let bytesPerRow = CVPixelBufferGetBytesPerRow(videoFrame!)
//                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
//                    
//                    let index = j*4 + i*Double(bytesPerRow)
//                    let b = buffer[Int(index)]
//                    let g = buffer[Int(index)+1]
//                    let r = buffer[Int(index)+2]
                
                
//                print(CGFloat(CVPixelBufferGetWidth(resizedBuffer!)))
                   
                
                    // Convert the depth frame format to cm
                    //let depthString = String(format: "%.2f cm", f32Pixel * 100)
                    //                    print(texturePoint.x, texturePoint.y)
                    //            print(depthPoint.x, depthPoint.y)
                    //                    print(depthString)
                if(realXrealYtoggle.isOn) {
                    let yRatio = Float(i / 640)
                    let xRatio = Float(j / 480)
                    //            let realZ = getDepth(from: depthPixelBuffer!, atXRatio: xRatio, atYRatio: yRatio)
                    let realX = (xRatio * 3019.0 - 1505.961) * f32Pixel * 100 / 2748.359
                    let realY = (yRatio * 4032.0 - 2023.0803) * f32Pixel * 100 / 2748.359
                    if((f32Pixel * 100) < 50) {
                        if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN) {
                            line.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100) + " ")
                        }
                    }
                } else {
                    if((f32Pixel * 100) < 50) {
                        if(!f32Pixel.isNaN) {
                            line.append(String(-f32Pixel * 100) + " ")
                        }
                    }
                }
                
                
                
//                if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN || (f32Pixel * 100) < 130) {
//                    output.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100) + " " + String(r) + " " + String(g) + " " + String(b))
//                }
                
                if(depthColorToggle.isOn) {
                    CVPixelBufferLockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                    let baseAddress = CVPixelBufferGetBaseAddress(resizedBuffer!)
                    let int32PerRow = CVPixelBufferGetBytesPerRow(resizedBuffer!)
                    if (baseAddress != nil) {
                        let int32Buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        
                        //                let bytesPerRow = CVPixelBufferGetBytesPerRow(movieFrame)
                        //                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        let index = (j) * 4 + (i) * Double(int32PerRow)
                        let b = int32Buffer[Int(index)]
                        let g = int32Buffer[Int(index)+1]
                        let r = int32Buffer[Int(index)+2]
                        
                        // Get BGRA value for pixel (43, 17)
                        //                let luma = int32Buffer[17 * int32PerRow + 43*4]
                        
                        CVPixelBufferUnlockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                        
                        line.append(String(r) + " " + String(g) + " " + String(b))
                    } else {
                        CVPixelBufferUnlockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                    }
                    
                
                }
                
                output.append(line)
                    
                //}
                // Update the label
                //            DispatchQueue.main.async {
                //                self.touchDepth.textColor = UIColor.white
                //                self.touchDepth.text = depthString
                //                self.touchDepth.sizeToFit()
                //            }
            }
        }
            
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(timeElapsed) s.")
        
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let dateString = df.string(from: date)
        
        // create the actual alert controller view that will be the pop-up
        let alertController = UIAlertController(title: "Point Cloud File Name", message: "name of point cloud", preferredStyle: .alert)

        alertController.addTextField { (textField) in
            // configure the properties of the text field
            textField.placeholder = "Name"
        }

        if(self.nameToggle.isOn) {
            var inputName: String?
            // add the buttons/actions to the view controller
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                
                // this code runs when the user hits the "save" button
                
                inputName = alertController.textFields![0].text
                print(inputName ?? "pointcloud")
                
                
                
                
                
                let modelName = self.device.model
                
                var systemInfo = utsname()
                uname(&systemInfo)
                let str = withUnsafePointer(to: &systemInfo.machine.0) { ptr in
                    return String(cString: ptr)
                }
                
                // Get the operating system name and version (e.g., "iOS 14.4")
                let osName = self.device.systemName
                let osVersion = self.device.systemVersion
                let osNameAndVersion = "\(osName) \(osVersion)"
                
                //print(output)
                
                let fileName = ( inputName ?? "pointcloud" ) + "_" + dateString + "_" + str + "_" + osNameAndVersion + ".xyz"
                
                //        let fileName = "point_cloud_" + dateString + ".xyz"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                let joineds = output.joined(separator: "\n")
                do {
                    try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
                } catch let e {
                    print(e)
                }
                
                //        let url = NSURLfileURL(withPath:fileName)
                
                if(self.imageToggle.isOn) {
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: self.imageData!, options: options)
                    }, completionHandler: { success, error in
                        if !success {
                            print("Couldn't save the photo to your photo library: \(String(describing: error))")
                        }
                    })
                }
                
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("Time elapsed: \(timeElapsed) s.")
                
                do {
                    let storageReference = Storage.storage().reference().child(fileName)
                    let currentUploadTask = storageReference.putFile(from: url) { (storageMetaData, error) in
                        if let error = error {
                            print("Upload error: \(error.localizedDescription)")
                            return
                        }
                        
                        // Show UIAlertController here
                        print("Image file: \(fileName) is uploaded! View it at Firebase console!")
                        
                        storageReference.downloadURL { (url, error) in
                            if let error = error  {
                                print("Error on getting download url: \(error.localizedDescription)")
                                return
                            }
                            print("Download url of \(fileName) is \(url!.absoluteString)")
                        }
                    }
                } catch {
                    print("Error on extracting data from url: \(error.localizedDescription)")
                }
            }
            
            
            alertController.addAction(cancelAction)
            alertController.addAction(saveAction)
            
            present(alertController, animated: true, completion: nil)
        } else {
            var inputName = "pointcloud"
            
            
            
            
            
            let modelName = self.device.model
            
            var systemInfo = utsname()
            uname(&systemInfo)
            let str = withUnsafePointer(to: &systemInfo.machine.0) { ptr in
                return String(cString: ptr)
            }

            // Get the operating system name and version (e.g., "iOS 14.4")
            let osName = self.device.systemName
            let osVersion = self.device.systemVersion
            let osNameAndVersion = "\(osName) \(osVersion)"
            
            //print(output)
            
            var url_a = [URL] ()
            var fileName = ( inputName ) + "_" + dateString + "_" + str + "_" + osNameAndVersion + ".xyz"
            
            //        let fileName = "point_cloud_" + dateString + ".xyz"
            var url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            let joineds = output.joined(separator: "\n")
            do {
                try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
            } catch let e {
                print(e)
            }
            
            //        let url = NSURLfileURL(withPath:fileName)
            
            url_a.append(url)
            
            if(self.imageToggle.isOn) {
//                PHPhotoLibrary.shared().performChanges({
//                    let options = PHAssetResourceCreationOptions()
//                    let creationRequest = PHAssetCreationRequest.forAsset()
//                    creationRequest.addResource(with: .photo, data: self.imageData!, options: options)
//                }, completionHandler: { success, error in
//                    if !success {
//                        print("Couldn't save the photo to your photo library: \(String(describing: error))")
//                    }
//                })
                var fileName1 = ( inputName ) + "_" + dateString + "_" + str + "_" + osNameAndVersion + ".jpg"
                url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName1)
                do {
                    try? self.actualImage!.jpegData(compressionQuality: 1.0)?.write(to: url, options: .atomic)
                }
                
                url_a.append(url)
                
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Time elapsed: \(timeElapsed) s.")
            
            var zipFilePath = URL(string: "")
            
            fileName = ( inputName ) + "_" + dateString + "_" + str + "_" + osNameAndVersion + ".zip"
            
            do {
                zipFilePath = try Zip.quickZipFiles(url_a, fileName: fileName)
                print("Zipping " + fileName)
            }
            catch {
                print("Unable to Zip file")
            }
            
            self.sessionZipFiles.append(zipFilePath!)
            
            do {
                let storageReference = Storage.storage().reference().child(fileName)
                let currentUploadTask = storageReference.putFile(from: zipFilePath!) { (storageMetaData, error) in
                    if let error = error {
                        print("Upload error: \(error.localizedDescription)")
                        return
                    }
                    
                    // Show UIAlertController here
                    print("Image file: \(fileName) is uploaded! View it at Firebase console!")
                    
                    storageReference.downloadURL { (url, error) in
                        if let error = error  {
                            print("Error on getting download url: \(error.localizedDescription)")
                            return
                        }
                        print("Download url of \(fileName) is \(url!.absoluteString)")
                    }
                }
            } catch {
                print("Error on extracting data from url: \(error.localizedDescription)")
            }
        }
    }
    
    
    @IBAction func save_session_zip(_ sender: Any) {
        
        // create the actual alert controller view that will be the pop-up
        let alertController = UIAlertController(title: "Session Archive File Name", message: "name of archive", preferredStyle: .alert)

        alertController.addTextField { (textField) in
            // configure the properties of the text field
            textField.placeholder = "Name"
        }
        
        var inputName: String?
        // add the buttons/actions to the view controller
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            
            // this code runs when the user hits the "save" button
            
            inputName = alertController.textFields![0].text
            print(inputName ?? "pointcloud")
            
            var zipFilePath = URL(string: "")
            
            do {
                zipFilePath = try Zip.quickZipFiles(self.sessionZipFiles, fileName: inputName! + ".zip")
                print("Zipping " + inputName!)
            }
            catch {
                print("Unable to Zip file")
            }
            
            let activityViewController = UIActivityViewController(activityItems: [zipFilePath!] , applicationActivities: nil)

            DispatchQueue.main.async {

                self.present(activityViewController, animated: true, completion: nil)
            }
            
        }
        
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        present(alertController, animated: true, completion: nil)
        
        
    }
    
    @IBAction func share_point_cloud(_ sender: Any) {
        
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
                    
//                let baseAddress = CVPixelBufferGetBaseAddress(videoFrame!)
//
//                let bytesPerRow = CVPixelBufferGetBytesPerRow(videoFrame!)
//                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
//
//                    let index = j*4 + i*Double(bytesPerRow)
//                    let b = buffer[Int(index)]
//                    let g = buffer[Int(index)+1]
//                    let r = buffer[Int(index)+2]
                
//                print(CGFloat(CVPixelBufferGetWidth(resizedBuffer!)))
                    
                    
                    // Convert the depth frame format to cm
                    //let depthString = String(format: "%.2f cm", f32Pixel * 100)
                    //                    print(texturePoint.x, texturePoint.y)
                    //            print(depthPoint.x, depthPoint.y)
                    //                    print(depthString)
                    
                if(realXrealYtoggle.isOn) {
                    let yRatio = Float(i / 640)
                    let xRatio = Float(j / 480)
                    //            let realZ = getDepth(from: depthPixelBuffer!, atXRatio: xRatio, atYRatio: yRatio)
                    let realX = (xRatio * 3019.0 - 1505.961) * f32Pixel * 100 / 2748.359
                    let realY = (yRatio * 4032.0 - 2023.0803) * f32Pixel * 100 / 2748.359
                    if((f32Pixel * 100) < 50) {
                        if(!realX.isNaN || !realY.isNaN || !f32Pixel.isNaN) {
                            output.append(String(-realX) + " " + String(-realY) + " " + String(-f32Pixel * 100) + " ")
                        }
                    }
                } else {
                    if((f32Pixel * 100) < 50) {
                        if(!f32Pixel.isNaN) {
                            output.append(String(-f32Pixel * 100) + " ")
                        }
                    }
                }
                
                if(depthColorToggle.isOn) {
                    CVPixelBufferLockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                    let baseAddress = CVPixelBufferGetBaseAddress(resizedBuffer!)
                    let int32PerRow = CVPixelBufferGetBytesPerRow(resizedBuffer!)
                    if (baseAddress != nil) {
                        let int32Buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        
                        //                let bytesPerRow = CVPixelBufferGetBytesPerRow(movieFrame)
                        //                    let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
                        
                        let index = (j) * 4 + (i) * Double(int32PerRow)
                        let b = int32Buffer[Int(index)]
                        let g = int32Buffer[Int(index)+1]
                        let r = int32Buffer[Int(index)+2]
                        
                        // Get BGRA value for pixel (43, 17)
                        //                let luma = int32Buffer[17 * int32PerRow + 43*4]
                        
                        CVPixelBufferUnlockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                        
                        output.append(String(r) + " " + String(g) + " " + String(b))
                    } else {
                        CVPixelBufferUnlockBaseAddress(resizedBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                    }
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
        
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let dateString = df.string(from: date)
        
        

        //print(output)
//        let fileName = pointcloudName.text! + dateString + ".xyz"
        
        let fileName = "pointcloud_" + dateString + ".xyz"
        
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        let joineds = output.joined(separator: "\n")
        do {
            try joineds.write(toFile: url.path, atomically: true, encoding: .utf8)
        } catch let e {
            print(e)
        }

        var zipFilePath = URL(string: "")
        
        
        do {
            zipFilePath = try Zip.quickZipFiles([url], fileName: "archive")
            print("Zipping " + fileName)
        }
        catch {
            print("Unable to Zip file")
        }
        
        let activityViewController = UIActivityViewController(activityItems: [zipFilePath!] , applicationActivities: nil)

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
        
        
    }
    
    private func testDepth(depth depthPixelBuffer: CVPixelBuffer, video videoFrame: CVPixelBuffer, i: CGFloat, j: CGFloat) -> Float{
        
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
            
//        print(scale)
//        print(CGFloat(CVPixelBufferGetWidth(depthPixelBuffer)))
//        print(CGFloat(CVPixelBufferGetWidth(videoFrame)))
        
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
            self.pixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer)!
            
            /**
             Resizes a CVPixelBuffer to a new width and height.
             */
            func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer,
                                   width: Int, height: Int) -> CVPixelBuffer? {
                return resizePixelBuffer(pixelBuffer, cropX: 0, cropY: 0,
                                         cropWidth: CVPixelBufferGetWidth(pixelBuffer),
                                         cropHeight: CVPixelBufferGetHeight(pixelBuffer),
                                         scaleWidth: width, scaleHeight: height)
            }
            
            func resizePixelBuffer(_ srcPixelBuffer: CVPixelBuffer,
                                   cropX: Int,
                                   cropY: Int,
                                   cropWidth: Int,
                                   cropHeight: Int,
                                   scaleWidth: Int,
                                   scaleHeight: Int) -> CVPixelBuffer? {
                
                CVPixelBufferLockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
                    print("Error: could not get pixel buffer base address")
                    return nil
                }
                let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
                let offset = cropY*srcBytesPerRow + cropX*4
                var srcBuffer = vImage_Buffer(data: srcData.advanced(by: offset),
                                              height: vImagePixelCount(cropHeight),
                                              width: vImagePixelCount(cropWidth),
                                              rowBytes: srcBytesPerRow)
                
                let destBytesPerRow = scaleWidth*4
                guard let destData = malloc(scaleHeight*destBytesPerRow) else {
                    print("Error: out of memory")
                    return nil
                }
                var destBuffer = vImage_Buffer(data: destData,
                                               height: vImagePixelCount(scaleHeight),
                                               width: vImagePixelCount(scaleWidth),
                                               rowBytes: destBytesPerRow)
                
                let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
                CVPixelBufferUnlockBaseAddress(srcPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                if error != kvImageNoError {
                    print("Error:", error)
                    free(destData)
                    return nil
                }
                
                let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
                    if let ptr = ptr {
                        free(UnsafeMutableRawPointer(mutating: ptr))
                    }
                }
                
                let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
                var dstPixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferCreateWithBytes(nil, scaleWidth, scaleHeight,
                                                          pixelFormat, destData,
                                                          destBytesPerRow, releaseCallback,
                                                          nil, nil, &dstPixelBuffer)
                if status != kCVReturnSuccess {
                    print("Error: could not create new pixel buffer")
                    free(destData)
                    return nil
                }
                return dstPixelBuffer
            }
            
            self.resizedBuffer = resizePixelBuffer(pixelBuffer!, width: 480, height: 640)
            
            if displayType == "video" {
                displayPixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer)
            } else if displayType == "depth"{
                displayPixelBuffer = syncedDepthData.depthData.depthDataMap
            }
            
            let image = CIImage(cvPixelBuffer: displayPixelBuffer!)
            let displayImage = UIImage(ciImage: image)
            self.actualImage = displayImage
            let quality = CGFloat(1.0)
            let context = CIContext()
            self.imageData = context.jpegRepresentation(of: image,
                                                        colorSpace: image.colorSpace!,
//                                                        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption : quality])!
                                                        options: [:])!
            DispatchQueue.main.async {
                self.image_view.image = displayImage
            }
        
        if(!self.nameToggle.isOn && self.frameCounter < 100 && self.frameCounter % 10 == 0) {
            
            self.frameCounter += 1
            print(frameCounter)
            //                self.depthFrameBuffer.append(self.depthPixelBuffer!)
            //                self.videoFrameBuffer.append(self.videoFrame!)
            
            //        if self.depthFrameBuffer.count > 4 {
            //                // Process and remove the oldest frames to maintain the buffer size
            //            self.depthFrameBuffer.removeFirst()
            //                self.videoFrameBuffer.removeFirst()
            //            }
            if let depthBufferCopy = copyPixelBuffer(pixelBuffer: depthPixelBuffer!),
               let videoFrameCopy = copyPixelBuffer(pixelBuffer: videoFrame!) {
                
                // Append the copies to your storage arrays
                self.depthFrameBuffer.append(depthBufferCopy)
                self.videoFrameBuffer.append(videoFrameCopy)
            }
            
        }
        if(!self.nameToggle.isOn && self.frameCounter < 100) {
            self.frameCounter += 1
        }
        
    }

    func copyPixelBuffer(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        var newPixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormatType, attributes, &newPixelBuffer)
        
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(newPixelBuffer!, [])
        
        let pixelBufferBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let newPixelBufferBaseAddress = CVPixelBufferGetBaseAddress(newPixelBuffer!)!
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufferLength = bytesPerRow * height
        
        memcpy(newPixelBufferBaseAddress, pixelBufferBaseAddress, bufferLength)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(newPixelBuffer!, [])
        
        return newPixelBuffer
    }

}


