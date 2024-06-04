//
//  FilterChain'.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/30/24.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct FilterChain {
    let filters: [(CIImage) -> CIImage?]
    func apply(to image: CIImage) -> CIImage? {
        var outputImage = image
        for filter in filters {
            guard let filteredImage = filter(outputImage) else { return nil } // Early return if filter fails
            outputImage = filteredImage
        }
        return outputImage
    }
}

func grayscaleFilter(image: CIImage) -> CIImage? {
    guard let filter = CIFilter(name: "CIColorControls") else { return nil }
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(0, forKey: kCIInputSaturationKey)
    return filter.outputImage
}


func depthNormalizeFilter(ciImage: CIImage, depthMin: Float = 0.0, depthMax: Float = 6.0) -> CIImage? {
    let depthNormalizationFilter = CIFilter(name: "CIColorMatrix")!
    depthNormalizationFilter.setValue(ciImage, forKey: kCIInputImageKey)
    depthNormalizationFilter.setValue(CIVector(x: 1 / CGFloat((depthMax - depthMin)), y: 0, z: 0, w: 0), forKey: "inputRVector")
    depthNormalizationFilter.setValue(CIVector(x: 0, y: 1 / CGFloat((depthMax - depthMin)), z: 0, w: 0), forKey: "inputGVector")
    depthNormalizationFilter.setValue(CIVector(x: 0, y: 0, z: 1 / CGFloat((depthMax - depthMin)), w: 0), forKey: "inputBVector")
    depthNormalizationFilter.setValue(CIVector(x: CGFloat(-depthMin / (depthMax - depthMin)), y: CGFloat(-depthMin / (depthMax - depthMin)), z: CGFloat(-depthMin / (depthMax - depthMin)), w: 1), forKey: "inputAVector")
    guard let normalizedDepthImage = depthNormalizationFilter.outputImage else { return nil }
    return normalizedDepthImage
}

func depthToHueRotationFilter(ciImage: CIImage, depthMin: Float = 0.0, depthMax: Float = 6.0) -> CIImage? {
    // ... (depth normalization logic - unchanged) ...
    guard let normalizedDepthImage = depthNormalizeFilter(ciImage: ciImage, depthMin: depthMin, depthMax: depthMax) else {
        return ciImage
    }

    // 2. Map Depth to Hue Angle
    let hueRotationAngle: Float = 180.0
    let hueRotationFilter = CIFilter(name: "CIHueAdjust")!
    hueRotationFilter.setValue(normalizedDepthImage, forKey: kCIInputImageKey)

    // Modified angle calculation using CIFilter:
    let hueRotationFilter2 = CIFilter(name: "CIMultiplyCompositing")!
    hueRotationFilter2.setValue(normalizedDepthImage, forKey: kCIInputBackgroundImageKey)
    hueRotationFilter2.setValue(CIImage(color: CIColor(hue: CGFloat(hueRotationAngle / 360.0), saturation: 1.0, brightness: 1.0)), forKey: kCIInputImageKey)

    // 3. Apply Filters and Return
    guard let multipliedImage = hueRotationFilter2.outputImage else { return nil }
    hueRotationFilter.setValue(multipliedImage, forKey: kCIInputImageKey)

    return hueRotationFilter.outputImage
}


extension CIColor {
    convenience init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        self.init(red: red, green: green, blue: blue)
    }
}

//func depthToHueRotationFilter(ciImage: CIImage, depthMin: Float = 0.0, depthMax: Float = 6.0) -> CIImage? {
//    // ... (depth normalization logic - unchanged) ...
//    guard let normalizedDepthImage = depthNormalizeFilter(ciImage: ciImage, depthMin: depthMin, depthMax: depthMax) else {
//        return ciImage
//    }
//    // 2. Map Depth to HSV
//    let hueRotationAngle: CGFloat = 180.0 // Use CGFloat for Core Image
//    let saturation: CGFloat = 1.0 // Full saturation
//    let brightness: CGFloat = 1.0 // Full brightness
//
//    // Create a filter chain to convert to HSV, adjust hue, and convert back to RGB
//    let colorControlsFilter = CIFilter(name: "CIColorControls")!
//    colorControlsFilter.setValue(normalizedDepthImage, forKey: kCIInputImageKey)
//    colorControlsFilter.setValue(0, forKey: kCIInputSaturationKey) // Desaturate
//    colorControlsFilter.setValue(brightness, forKey: kCIInputBrightnessKey) // Set brightness
//
//    let hueFilter = CIFilter(name: "CIHueAdjust")!
//    hueFilter.setValue(colorControlsFilter.outputImage, forKey: kCIInputImageKey)
//
//    // Calculate hue rotation based on depth (adjust this mapping as needed)
//    let angleExpression = NSExpression(format: "\(hueRotationAngle) * \(normalizedDepthImage.extent.width) * (r - \(depthMin)) / (\(depthMax) - \(depthMin))")
//    hueFilter.setValue(angleExpression, forKey: kCIInputAngleKey)
//
//    let colorControlsFilter2 = CIFilter(name: "CIColorControls")!
//    colorControlsFilter2.setValue(hueFilter.outputImage, forKey: kCIInputImageKey)
//    colorControlsFilter2.setValue(saturation, forKey: kCIInputSaturationKey) // Restore saturation
//
//    // 3. Apply Filter and Return
//    return colorControlsFilter2.outputImage
//}
