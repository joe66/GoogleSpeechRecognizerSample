//
//  ViewController.swift
//  GoogleSpeechRecognizerSample
//
//  Created by 服部 智 on 2017/12/18.
//  Copyright © 2017年 SHMDevelopment. All rights reserved.
//

import UIKit
import AVFoundation
import googleapis

let SAMPLE_RATE = 16000

class ViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var streamButton: UIButton! {
        didSet {
            streamButton.layer.cornerRadius = 10
        }
    }
    @IBOutlet weak var recordButton: UIButton! {
        didSet {
            recordButton.layer.cornerRadius = 10
        }
    }

    var audioData: NSMutableData!
    var isStreaming = false
    var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        AudioController.sharedInstance.delegate = self
        AudioRESTController.sharedInstance.prepare(delegate: self)
    }

    @IBAction func streamButtonAction(_ sender: Any) {
        if !isStreaming {
            streamButton.setTitle("Stop", for: .normal)
            streamButton.backgroundColor = UIColor.red
            startStreaming()
        } else {
            streamButton.setTitle("Start Streaming", for: .normal)
            streamButton.backgroundColor = UIColor.clear
            stopStreaming()
        }
        isStreaming = !isStreaming
    }
    
    @IBAction func recordButtonAction(_ sender: Any) {
        if !isRecording {
            recordButton.setTitle("Stop", for: .normal)
            recordButton.backgroundColor = UIColor.red
            AudioRESTController.sharedInstance.record()
        } else {
            recordButton.setTitle("Start Rec", for: .normal)
            recordButton.backgroundColor = UIColor.clear
            AudioRESTController.sharedInstance.stop()
            AudioRESTController.sharedInstance.soundFileToText()
        }
        isRecording = !isRecording
    }

    private func startStreaming() {
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryRecord)
        audioData = NSMutableData()
        _ = AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE)
        SpeechRecognitionService.sharedInstance.sampleRate = SAMPLE_RATE
        _ = AudioController.sharedInstance.start()
    }

    private func stopStreaming() {
        _ = AudioController.sharedInstance.stop()
        SpeechRecognitionService.sharedInstance.stopStreaming()
    }
}

extension ViewController: AudioControllerDelegate {
    func processSampleData(_ data: Data) -> Void {
        audioData.append(data)

        // We recommend sending samples in 100ms chunks
        let chunkSize : Int /* bytes/chunk */ = Int(0.1 /* seconds/chunk */
            * Double(SAMPLE_RATE) /* samples/second */
            * 2 /* bytes/sample */);

        if (audioData.length > chunkSize) {
            SpeechRecognitionService.sharedInstance.streamAudioData(audioData, completion: { [weak self] (response, error) in
                guard let strongSelf = self else {
                    return
                }

                if let error = error {
                    strongSelf.textView.text = error.localizedDescription
                } else if let response = response {
                    var finished = false
                    print(response)
                    for result in response.resultsArray! {
                        if let result = result as? StreamingRecognitionResult {
                            if result.isFinal {
                                finished = true
                            }
                        }
                    }
                    strongSelf.textView.text = response.description
                    if finished {
                        strongSelf.stopStreaming()
                    }
                }
            })
            self.audioData = NSMutableData()
        }
    }
}

extension ViewController: AudioRESTControllerDelegate {
    func doneAnalyze(_ items: [String]) -> Void {
        if items.isEmpty { return }
        textView.text = items.joined(separator: ", ")
    }
}
