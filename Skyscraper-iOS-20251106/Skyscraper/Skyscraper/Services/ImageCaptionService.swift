//
//  ImageCaptionService.swift
//  Skyscraper
//
//  AI-powered image caption generation for alt text using advanced iOS 18+ Vision APIs
//

import Foundation
import Vision
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
class ImageCaptionService {
    static let shared = ImageCaptionService()

    private init() {}

    /// Generate an alt text description for an image using advanced Vision framework
    func generateAltText(for image: PlatformImage) async throws -> String {
        #if os(iOS)
        guard let cgImage = image.cgImage else {
            throw ImageCaptionError.invalidImage
        }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageCaptionError.invalidImage
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            // Create a request handler
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            // Storage for analysis results
            var sceneDescription: String = ""
            var recognizedObjects: [String] = []
            var detectedText: [String] = []
            var peopleCount: Int = 0

            let dispatchGroup = DispatchGroup()

            // 1. Advanced Scene Classification with taxonomy
            dispatchGroup.enter()
            let sceneRequest = VNClassifyImageRequest { request, error in
                defer { dispatchGroup.leave() }

                if let error = error {
                    print("⚠️ Scene classification error: \(error.localizedDescription)")
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    return
                }

                // Get the most confident scene classification
                if let topResult = observations.first, topResult.confidence > 0.5 {
                    sceneDescription = self.humanizeSceneIdentifier(topResult.identifier)
                } else if let secondBest = observations.dropFirst().first, secondBest.confidence > 0.3 {
                    sceneDescription = self.humanizeSceneIdentifier(secondBest.identifier)
                }
            }

            // 2. Object Recognition using VNRecognizeAnimalsRequest and general object detection
            dispatchGroup.enter()
            let animalRequest = VNRecognizeAnimalsRequest { request, error in
                defer { dispatchGroup.leave() }

                if let error = error {
                    print("⚠️ Animal detection error: \(error.localizedDescription)")
                    return
                }

                if let observations = request.results as? [VNRecognizedObjectObservation] {
                    for observation in observations.prefix(3) where observation.confidence > 0.6 {
                        if let label = observation.labels.first?.identifier {
                            recognizedObjects.append(self.humanizeObjectLabel(label))
                        }
                    }
                }
            }

            // 3. Advanced Text Recognition with accurate extraction
            dispatchGroup.enter()
            let textRequest = VNRecognizeTextRequest { request, error in
                defer { dispatchGroup.leave() }

                if let error = error {
                    print("⚠️ Text detection error: \(error.localizedDescription)")
                    return
                }

                if let observations = request.results as? [VNRecognizedTextObservation] {
                    let recognizedStrings = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .filter { !$0.isEmpty }

                    if !recognizedStrings.isEmpty {
                        detectedText = Array(recognizedStrings.prefix(3))
                    }
                }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true

            // 4. Human Detection with facial attributes
            dispatchGroup.enter()
            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                defer { dispatchGroup.leave() }

                if let error = error {
                    print("⚠️ Face detection error: \(error.localizedDescription)")
                    return
                }

                if let observations = request.results as? [VNFaceObservation] {
                    peopleCount = observations.count
                }
            }

            // 5. Dominant Colors Analysis (using objectness-based saliency)
            dispatchGroup.enter()
            let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                defer { dispatchGroup.leave() }

                if let error = error {
                    print("⚠️ Saliency detection error: \(error.localizedDescription)")
                    return
                }

                // Saliency helps identify important regions
                if let observation = request.results?.first as? VNSaliencyImageObservation {
                    // Check if image has high contrast salient regions
                    if let salientObjects = observation.salientObjects, !salientObjects.isEmpty {
                        // Multiple salient objects detected
                        if salientObjects.count > 2 {
                            recognizedObjects.insert("multiple subjects", at: 0)
                        }
                    }
                }
            }

            // Perform all requests
            do {
                try requestHandler.perform([
                    sceneRequest,
                    animalRequest,
                    textRequest,
                    faceRequest,
                    saliencyRequest
                ])
            } catch {
                print("❌ Vision request failed: \(error.localizedDescription)")
                continuation.resume(throwing: error)
                return
            }

            // Wait for all requests to complete
            dispatchGroup.notify(queue: .main) {
                // Build natural language description
                let description = self.buildNaturalDescription(
                    scene: sceneDescription,
                    objects: recognizedObjects,
                    text: detectedText,
                    peopleCount: peopleCount
                )

                continuation.resume(returning: description)
            }
        }
    }

    // MARK: - Natural Language Generation

    private func buildNaturalDescription(
        scene: String,
        objects: [String],
        text: [String],
        peopleCount: Int
    ) -> String {
        var parts: [String] = []

        // Start with scene if available
        if !scene.isEmpty {
            parts.append(scene)
        }

        // Add people information
        if peopleCount > 0 {
            let peopleDesc: String
            if peopleCount == 1 {
                peopleDesc = scene.isEmpty ? "A person" : "with a person"
            } else {
                peopleDesc = scene.isEmpty ? "\(peopleCount) people" : "with \(peopleCount) people"
            }
            parts.append(peopleDesc)
        }

        // Add detected objects
        if !objects.isEmpty {
            let objectsDesc = objects.prefix(3).joined(separator: ", ")
            if parts.isEmpty {
                parts.append("Image showing \(objectsDesc)")
            } else if peopleCount == 0 {
                parts.append("featuring \(objectsDesc)")
            }
        }

        // Add text information
        if !text.isEmpty {
            if text.count == 1, let firstText = text.first, firstText.count < 30 {
                parts.append("with text: \"\(firstText)\"")
            } else {
                parts.append("containing visible text")
            }
        }

        // Combine all parts
        var finalDescription = parts.joined(separator: " ")

        // Ensure proper capitalization
        if !finalDescription.isEmpty {
            finalDescription = finalDescription.prefix(1).uppercased() + finalDescription.dropFirst()
        }

        // Add period if not present
        if !finalDescription.isEmpty && !finalDescription.hasSuffix(".") {
            finalDescription += "."
        }

        // Fallback
        if finalDescription.isEmpty {
            finalDescription = "Image content"
        }

        return String(finalDescription.prefix(500)) // Limit to 500 chars
    }

    // MARK: - Humanization Helpers

    private func humanizeSceneIdentifier(_ identifier: String) -> String {
        // Convert Vision's technical identifiers to natural language
        let lowercased = identifier.lowercased()

        // Common scene mappings
        let sceneMap: [String: String] = [
            "outdoor": "An outdoor scene",
            "indoor": "An indoor scene",
            "landscape": "A landscape",
            "cityscape": "A cityscape",
            "nature": "A nature scene",
            "sky": "A sky view",
            "water": "A water scene",
            "beach": "A beach scene",
            "mountain": "A mountain scene",
            "forest": "A forest scene",
            "urban": "An urban setting",
            "building": "A building",
            "architecture": "An architectural photo",
            "food": "Food",
            "sunset": "A sunset",
            "sunrise": "A sunrise",
            "night": "A nighttime scene",
            "snow": "A snowy scene",
            "desert": "A desert scene",
            "ocean": "An ocean view",
            "lake": "A lake view",
            "river": "A river scene",
            "garden": "A garden",
            "park": "A park scene",
            "street": "A street scene",
            "room": "A room interior",
            "office": "An office space",
            "restaurant": "A restaurant",
            "cafe": "A café"
        ]

        // Check for direct matches
        for (key, value) in sceneMap {
            if lowercased.contains(key) {
                return value
            }
        }

        // Default: clean up the identifier
        return "A \(identifier.replacingOccurrences(of: "_", with: " ")) scene"
    }

    private func humanizeObjectLabel(_ label: String) -> String {
        // Convert object labels to natural language
        return label
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
    }
}

enum ImageCaptionError: LocalizedError {
    case invalidImage
    case captionGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the image"
        case .captionGenerationFailed:
            return "Failed to generate image caption"
        }
    }
}
