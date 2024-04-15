//
//  ContentView.swift
//  Reality Parser
//
//  Created by 罗天宁 on 25/04/2022.
//

import SwiftUI

struct ContentView: View {
    
    @State var inputFolder = ""
    @State var outputFolder = ""
    var details = [String(localized: "Reduced"), String(localized: "Medium"), String(localized: "Full"), String(localized: "Raw")]
    @State var detail = String(localized: "Medium")
    var orders = [String(localized: "Unordered"), String(localized: "Sequential")]
    @State var ordered = String(localized: "Sequential")
    var sensitivities = [String(localized: "Normal"), String(localized: "High")]
    @State var sensitivity = String(localized: "Normal")
    @State var processing = String(localized: "Process!")
    @State var stop = String(localized: "Stop")
    @StateObject var constructor = Constructor.init()
    @State var languageSet = Locale.current.language.languageCode?.identifier
    @State public var progress = 0.0
    @State public var compeleted = false
    
    var body: some View {
        VStack {
            Text("Reality Parser").padding([.bottom], 5).font(.system(size: 30, weight: .bold, design: .monospaced));
            Group {
                Label(String(localized: "Input"), systemImage: "1.circle")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                .padding([.bottom], 1)
                Button(String(localized: "Select Folder")) {
                    inputFolder = self.selectInputFolder()
                    print(String(localized: "Input Folder selected: ") + inputFolder)
                }.padding([.bottom], 5)
                HStack {
                    if (inputFolder != "") {
                        Image(systemName: "checkmark.circle").foregroundColor(Color.green)
                        Text(inputFolder).font(.system(size: 11))
                    } else {
                        Image(systemName: "x.circle").foregroundColor(Color.red)
                        Text(String(localized: "Input folder not selected.")).font(.system(size: 11))
                    }
                }.padding([.bottom], 2)
            }
            VStack {
                Label(String(localized: "Output"), systemImage: "2.circle")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .padding([.bottom], 1);
                HStack{
                    Button(String(localized: "Select Folder")) {
                        self.outputFolder = self.selectOutputFolder()
                        self.outputFolder = self.selectOutputFolder()
                    }.padding([.bottom], 5)
                }
                HStack {
                    if (outputFolder != "") {
                        Image(systemName: "checkmark.circle").foregroundColor(Color.green)
                        Text(outputFolder).font(.system(size: 11))
                    } else {
                        Image(systemName: "x.circle").foregroundColor(Color.red)
                        Text(String(localized: "Output location not selected.")).font(.system(size: 11))
                    }
                }.padding([.bottom], 2)
            }
            VStack {
                Label(String(localized: "Preferences"), systemImage: "3.circle")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .padding([.bottom], 1)
                Picker(String(localized: "Detail"), selection: $detail) {
                    ForEach(details, id: \.self) {
                        Text($0)
                    }
                }.pickerStyle(.segmented)
                Text(String(localized: "Reduced and Medium are IOS ready, Full and Raw require further processing."))
                    .font(.system(size: 9))
                Picker(String(localized: "Order"), selection: $ordered) {
                    ForEach(orders, id: \.self) {
                        Text($0)
                    }
                }.pickerStyle(.segmented)
                Text(String(localized: "Setting to sequential may speed up computation.")).font(.system(size: 9))
                Picker(String(localized: "Sensitivity"), selection: $sensitivity) {
                    ForEach(sensitivities, id: \.self) {
                        Text($0)
                    }
                }.pickerStyle(.segmented)
                Text(String(localized: "High if the scanned object does not contain discernible structures, edges or textures."))
                    .font(.system(size: 9))
                ProgressView(value: progress)
            }
            HStack {
                Button(processing) {
                    if(inputFolder != "" && outputFolder != "") {
                        do{
                            
                            var detailSetting = "medium"
                            switch detail{
                            case String(localized: "Reduced"):
                                detailSetting = "reduced"
                            case String(localized: "Full"):
                                detailSetting = "full"
                            case String(localized: "Raw"):
                                detailSetting = "raw"
                            default:
                                detailSetting = "medium"
                            }
                            
                            self.progress = 0.0
                            self.compeleted = false
                            let fileManager = FileManager()
                            let tempDirectory = fileManager.temporaryDirectory.appending(component: "modelTemp/").path()
                            try constructor.process(inputFolder: inputFolder, outputFilename: tempDirectory,
                                                    detail: detailSetting,
                                                    ordering: ordered == orders[0] ? "unordered" : "sequential",
                                                    sensitivity: sensitivity == sensitivities[0] ? "normal" : "high",
                                                    contentView: self,
                                                    resultPath: self.outputFolder)
                        } catch {
                            print((String(describing: error)))
                        }
                    }
                    if (progress == 1.0) {
                        processing = String(localized: "Done!")
                    } else if (progress != 0.0) {
                        processing = String(localized: "Processing...")
                    }
                }.disabled(inputFolder == "" || outputFolder == "" || (progress != 0.0 && !self.compeleted))
                Button(stop) {
                    constructor.cancelSession()
                }.disabled((progress == 0.0 || self.compeleted))
            }
        }
    }
    
    private func selectInputFolder() -> String{
        let openPanel = NSOpenPanel();

        openPanel.title = String(localized: "Select folder contains images, depth images and rotation data");
        openPanel.showsResizeIndicator = true;
        openPanel.allowsMultipleSelection = false;
        openPanel.canChooseDirectories = true;
        openPanel.canChooseFiles = false;

        if (openPanel.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = openPanel.url

            if (result != nil) {
                return result!.path
            }
        }
        return "";
    }
    
    private func selectOutputFolder() -> String{
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "Select folder for the output:"); /// @TODO
        savePanel.showsResizeIndicator = true;
        savePanel.nameFieldStringValue = String(localized: "Untitled.usdz")
        
        if (savePanel.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = savePanel.url
            if (result != nil) {
                return result!.path
            }
        }
        return "";
    }
    
    public func updateProgress(fractionComplete: Double) {
        self.progress = fractionComplete
    }
    
    func changeLanguage() {
        print(Locale.current.identifier)
    }
}
