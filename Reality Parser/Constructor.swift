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
import ZIPFoundation

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
    private static var resultPath = ""
    
    /// The main run loop entered at the end of the file.
    func process(inputFolder: String, outputFilename: String, detail: String, ordering: String, sensitivity: String, contentView: ContentView, resultPath: String) throws {
        
        /// Check hardware meets requirement.
        guard PhotogrammetrySession.isSupported else {
            throw IllegalOption.invalidHardware("Program terminated early because the hardware doesn't support Object Capture.\nObject Capture is not available on this computer.")
        }
        
        Constructor.resultPath = resultPath
        
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
        
        /// Remove present file.
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: resultPath) {
            do {
                try fileManager.removeItem(atPath: resultPath)
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
        print("Request complete: \(String(describing: request))")
        switch result {
        case .modelFile(let url):
        
        /// Converts USDA and assets to USDZ
//        Constructor.convert(url: url);
            
        /// Clean up temp folders
        do {
            let fileManager = FileManager()
            let tmpDirectory = try fileManager.contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned fileManager] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try fileManager.removeItem(atPath: path)
            }
            print("Cleared photogrammetry session cache")
        } catch {
            print("Cleanup error: \(String(describing: error))")
        }
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
    
    /// Converts usdc crate in result to usda text format
    private static func convert(url: URL){
//        do {
//            let fileManager = FileManager()
//            let currentWorkingURL = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "modelTemp/")


//
//            var output = URL(fileURLWithPath: self.resultPath)
//            print("From: " + String(describing: currentWorkingURL) + " To: " + String(describing: output))
//            try fileManager.zipItem(at: currentWorkingURL,
//                                    to: output)
//            let currentWorkingPath = fileManager.currentDirectoryPath
//            var sourceURL = URL(fileURLWithPath: currentWorkingPath)
//            sourceURL.appendPathComponent("/tmp/modelTemp/")
//            let USDZFolder = sourceURL.appending(path: "0/")
//            try fileManager.createDirectory(at: USDZFolder, withIntermediateDirectories: true)
//            try fileManager.moveItem(at: sourceURL.appending(path: "baked_mesh_ao0.png"), to: USDZFolder.appending(path: "baked_mesh_ao0.png"))
//            try fileManager.moveItem(at: sourceURL.appending(path: "baked_mesh_norm0.png"), to: USDZFolder.appending(path: "baked_mesh_norm0.png"))
//            try fileManager.moveItem(at: sourceURL.appending(path: "baked_mesh_tex0.png"), to: USDZFolder.appending(path: "baked_mesh_tex0.png"))
//            try fileManager.removeItem(at: sourceURL.appending(path: "baked_mesh.mtl"))
//            try fileManager.removeItem(at: sourceURL.appending(path: "baked_mesh.obj"))
//            var destinationURL = URL(fileURLWithPath: currentWorkingPath)
//            destinationURL.appendPathComponent("archive.usdz")
//            try fileManager.zipItem(at: sourceURL, to: destinationURL)
//        } catch {
//            print("Creation of ZIP archive failed with error:\(error)")
//        }
    }
}
