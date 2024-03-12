//
//  Constructor.swift
//  Reality Parser
//
//  Created by 罗天宁 on 25/04/2022.
//

import Foundation
import os
import RealityKit
import Metal

/// Error thrown when an illegal option is specified.
private enum IllegalOption: Swift.Error {
    case invalidHardware(String)
    case sessionCreationError(String)
    case SessionNotCreated(String)
    case requestError(String)
    case generalError(String)
    case fileRemoveError(String)
}

class Constructor:ObservableObject {
    
    private typealias Configuration = PhotogrammetrySession.Configuration
    private typealias Request = PhotogrammetrySession.Request
    private var sampleOrdering: Configuration.SampleOrdering?
    private var featureSensitivity: Configuration.FeatureSensitivity?
    private var session: PhotogrammetrySession? = nil
    
    /// The main run loop entered at the end of the file.
    func process(inputFolder: String, outputFilename: String, detail: String, ordering: String, sensitivity: String, contentView: ContentView) throws {
        
        /// Check hardware meets requirement.
        guard PhotogrammetrySession.isSupported else {
            throw IllegalOption.invalidHardware("Program terminated early because the hardware doesn't support Object Capture.\nObject Capture is not available on this computer.")
        }
        
        let inputFolderUrl = URL(fileURLWithPath: inputFolder, isDirectory: true)
        var configuration = PhotogrammetrySession.Configuration()
        configuration.sampleOrdering = ordering == "sequential" ? Configuration.SampleOrdering.sequential : Configuration.SampleOrdering.unordered
        configuration.featureSensitivity = sensitivity == "normal" ? Configuration.FeatureSensitivity.normal : Configuration.FeatureSensitivity.high
        print("Using configuration: \(String(describing: configuration))")
        
        var detailSetting = Request.Detail.medium;
        switch(detail) {
        case "reduced":
            detailSetting = Request.Detail.reduced;
        case "full":
            detailSetting = Request.Detail.full;
        case "raw":
            detailSetting = Request.Detail.raw;
        default:
            break;
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputFilename) {
            do {
                try fileManager.removeItem(atPath: outputFilename)
            } catch let error {
                throw IllegalOption.fileRemoveError("Cannot replace file: \n \(String(describing: error))")
            }
        }
        
        let request = PhotogrammetrySession.Request.modelFile(url: URL(fileURLWithPath: outputFilename), detail: detailSetting)
        
        // Try to create the session.
        var maybeSession: PhotogrammetrySession? = nil
        do {
            maybeSession = try PhotogrammetrySession(input: inputFolderUrl,
                                                     configuration: configuration)
            print("Successfully created session.")
        } catch {
            throw IllegalOption.sessionCreationError("Error creating session: \(String(describing: error))")
        }
        guard let session = maybeSession else {
            throw IllegalOption.sessionCreationError("Session not created.")
        }
        self.session = maybeSession
        
        let waiter = Task {
            do {
                for try await output in session.outputs {
                    switch output {
                    case .processingComplete:
                        print("Processing is complete!")
                    case .requestError(let request, let error):
                        await contentView.updateProgress(fractionComplete: 0.0)
                        throw IllegalOption.requestError("Request \(String(describing: request)) had an error: \(String(describing: error))")
                    case .requestComplete(let request, let result):
                        Constructor.handleRequestComplete(request: request, result: result, contentView: contentView)
                    case .requestProgress(_, let fractionComplete):
                        await contentView.updateProgress(fractionComplete: fractionComplete)
                    case .inputComplete:  // data ingestion only!
                        print("Data ingestion is complete.  Beginning processing...")
                    case .invalidSample(let id, let reason):
                        print("Invalid Sample! id=\(id)  reason=\"\(reason)\"")
                    case .skippedSample(let id):
                        print("Sample id=\(id) was skipped by processing.")
                    case .automaticDownsampling:
                        print("Automatic downsampling was applied!")
                    case .processingCancelled:
                        print("Processing was cancelled.")
                    case .requestProgressInfo(_, _): break
                    case .stitchingIncomplete:
                        print("Stitching incompete!")
                    @unknown default:
                        print("Output: unhandled message: \(output.localizedDescription)")
                        
                    }
                }
            } catch {
                await contentView.updateProgress(fractionComplete: 0.0)
                throw IllegalOption.generalError("Output: ERROR = \(String(describing: error))")
            }
        }
        
        // The compiler may deinitialize these objects since they may appear to be unused. This keeps them from being deallocated.
        do {
            try withExtendedLifetime((session, waiter)) {
                // Run the main process call on the request, you get the published completion event or error.
                print("Using request: \(String(describing: request))")
                try session.process(requests: [ request ])
            }
        }catch {
                throw IllegalOption.generalError("Process got error: \(String(describing: error))")
        }
    }
    
    /// Called when the the session sends a request completed message.
    private static func handleRequestComplete(request: PhotogrammetrySession.Request,
                                              result: PhotogrammetrySession.Result,
                                              contentView: ContentView) {
        print("Request complete: \(String(describing: request)) with result...")
        switch result {
        case .modelFile(let url):
            print("\tmodelFile available at url=\(url)")
        default:
            print("\tUnexpected result: \(String(describing: result))")
        }
        contentView.compeleted = true
    }

    
    /// Called when request session cancel
    public func cancelSession() {
        if self.session != nil {
            self.session?.cancel()
        }
    }
}
