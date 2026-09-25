import Flutter
import UIKit
import Vision
import CoreImage

/// Expone `VNGenerateForegroundInstanceMaskRequest` (Apple Vision) a Flutter vía MethodChannel,
/// para remoción de fondo on-device de prendas del guardarropa. iOS 17+ únicamente.
final class BackgroundRemovalChannel: NSObject {
  static let channelName = "com.aifit/background_removal"
  private let ciContext = CIContext()

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "removeBackground" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments as? [String: Any],
          let data = args["imageBytes"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "imageBytes es requerido", details: nil))
      return
    }

    guard #available(iOS 17.0, *) else {
      result(FlutterError(code: "UNSUPPORTED_OS", message: "Requiere iOS 17 o superior", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      do {
        let pngBytes = try self.generateCutoutPng(from: data.data)
        DispatchQueue.main.async { result(pngBytes) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "SEGMENTATION_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  @available(iOS 17.0, *)
  private func generateCutoutPng(from imageData: Data) throws -> Data {
    guard let ciImage = CIImage(data: imageData) else {
      throw NSError(domain: "BackgroundRemoval", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "No se pudo decodificar la imagen de entrada",
      ])
    }

    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    try handler.perform([request])

    guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
      throw NSError(domain: "BackgroundRemoval", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "No se detectó ningún objeto en foreground",
      ])
    }

    let maskPixelBuffer = try observation.generateScaledMaskForImage(
      forInstances: observation.allInstances,
      from: handler
    )
    let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
    let cutout = ciImage.applyingFilter("CIBlendWithMask", parameters: [
      kCIInputMaskImageKey: maskImage,
    ])

    guard let cgImage = ciContext.createCGImage(cutout, from: cutout.extent) else {
      throw NSError(domain: "BackgroundRemoval", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "No se pudo renderizar el cutout final",
      ])
    }

    let uiImage = UIImage(cgImage: cgImage)
    guard let pngData = uiImage.pngData() else {
      throw NSError(domain: "BackgroundRemoval", code: 4, userInfo: [
        NSLocalizedDescriptionKey: "No se pudo codificar el cutout a PNG",
      ])
    }

    return pngData
  }
}
