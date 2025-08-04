#!/usr/bin/swift

import Cocoa
import AVFoundation
import Carbon

class SpeechWidgetApp: NSObject, NSApplicationDelegate, AVAudioRecorderDelegate {
    var statusItem: NSStatusItem!
    var isListening = false
    var audioRecorder: AVAudioRecorder?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Speech to Text")
            button.action = #selector(menuClicked)
        }
        
        setupMenu()
        setupGlobalHotkey()
        requestPermissions()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Listening (Fn)", action: #selector(toggleListening), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Test", action: #selector(testInsert), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func testInsert() {
        insertTextAtCursor("Hello from Speech Widget!")
    }
    
    func setupGlobalHotkey() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if event.keyCode == 63 {
                if event.modifierFlags.contains(.function) && !(self?.isListening ?? false) {
                    self?.toggleListening()
                } else if !event.modifierFlags.contains(.function) && (self?.isListening ?? false) {
                    self?.toggleListening()
                }
            }
        }
    }
    
    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showAlert(title: "Microphone Access Required", 
                                   message: "Please grant microphone access in System Preferences")
                }
            }
        }
        
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            showAlert(title: "Accessibility Access Required", 
                      message: "Please grant accessibility access in System Preferences")
        }
    }
    
    @objc func toggleListening() {
        isListening.toggle()
        updateStatusIcon()
        
        if isListening {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        let tempDir = NSTemporaryDirectory()
        let audioFilename = URL(fileURLWithPath: tempDir).appendingPathComponent("recording.wav")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String : Any]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            showAlert(title: "Recording Error", message: error.localizedDescription)
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            transcribeWithWhisper(audioFile: recorder.url)
        }
    }
    
    func transcribeWithWhisper(audioFile: URL) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let outputDir = NSTemporaryDirectory()
        
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["python3", "-m", "whisper", audioFile.path, "--model", "tiny", "--output_format", "txt", "--language", "en", "--output_dir", outputDir]
        
        var environment = ProcessInfo.processInfo.environment
        let currentPath = environment["PATH"] ?? ""
        environment["PATH"] = "\(homeDir)/bin:/usr/local/bin:\(currentPath)"
        task.environment = environment
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            let txtFile = audioFile.deletingPathExtension().appendingPathExtension("txt")
            
            if let transcription = try? String(contentsOf: txtFile, encoding: .utf8) {
                let cleanText = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanText.isEmpty {
                    insertTextAtCursor(cleanText)
                } else {
                    insertTextAtCursor("(no speech detected)")
                }
                
                try? FileManager.default.removeItem(at: txtFile)
            } else {
                insertTextAtCursor("(transcription failed)")
            }
        } else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            if errorOutput.contains("ffmpeg") {
                showAlert(title: "FFmpeg Issue", 
                         message: "FFmpeg not found. Installing...")
                installFFmpeg()
            } else {
                insertTextAtCursor("(whisper error)")
            }
        }
        
        try? FileManager.default.removeItem(at: audioFile)
    }
    
    func installFFmpeg() {
        insertTextAtCursor("Installing ffmpeg, please wait...")
    }
    
    func insertTextAtCursor(_ text: String) {
        guard !text.isEmpty else { return }
        
        let source = CGEventSource(stateID: .hidSystemState)
        let pasteBoard = NSPasteboard.general
        let oldContent = pasteBoard.string(forType: .string)
        
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        
        let cmdV = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        cmdV?.flags = .maskCommand
        cmdV?.post(tap: .cghidEventTap)
        
        Thread.sleep(forTimeInterval: 0.05)
        
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdVUp?.flags = .maskCommand
        cmdVUp?.post(tap: .cghidEventTap)
        
        Thread.sleep(forTimeInterval: 0.1)
        
        if let oldContent = oldContent {
            pasteBoard.clearContents()
            pasteBoard.setString(oldContent, forType: .string)
        }
    }
    
    func updateStatusIcon() {
        if let button = statusItem.button {
            if isListening {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
                button.image?.isTemplate = false
            } else {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Speech to Text")
                button.image?.isTemplate = true
            }
        }
    }
    
    @objc func menuClicked() {
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = SpeechWidgetApp()
app.delegate = delegate
app.run()