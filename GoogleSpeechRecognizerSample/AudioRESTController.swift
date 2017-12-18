//
//  AudioRESTController.swift
//  Speech
//
//  Created by satoshi0212 on 2017/12/09.
//  Copyright © 2017年 Google. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioRESTControllerDelegate {
    func doneAnalyze(_ items: [String]) -> Void
}

class AudioRESTController: NSObject, AVAudioRecorderDelegate {
    var delegate : AudioRESTControllerDelegate!
    static var sharedInstance = AudioRESTController()
    
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?

    var loudTimer: Timer? = nil

    var soundFilePath: String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask , true)
        guard let path = paths.first else { return "" }
        return path.appending("/sound.caf")
    }

    func prepare(delegate: AudioRESTControllerDelegate) {
        self.delegate = delegate
        AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
            if allowed {
                print(self.soundFilePath)
            } else {
            }
        }
        
        let soundFileURL = URL(fileURLWithPath: soundFilePath)
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            try session.setMode(AVAudioSessionModeMeasurement)
            try session.setActive(true)
            let settings = [
                AVSampleRateKey: SAMPLE_RATE,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 16,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: soundFileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
        }
        catch let error {
            print(error)
        }
    }

    func record() {
        audioRecorder?.record(forDuration: 15)
    }

    func stop() {
        audioRecorder?.stop()
    }
    
    // 音声ファイルからテキスト抽出
    func soundFileToText() {
        let service = "https://speech.googleapis.com/v1/speech:recognize?key=\(API_KEY)"
        let data = try! Data(contentsOf: URL(fileURLWithPath: soundFilePath))
        let config: [String: Any] = [
            "encoding": "LINEAR16",
            "sampleRateHertz": "\(SAMPLE_RATE)",
            "languageCode": "ja-JP",
            "maxAlternatives": 1]
        
        let audioRequest = ["content": data.base64EncodedString()]
        let requestDictionary = ["config": config, "audio": audioRequest]
        let requestData = try! JSONSerialization.data(withJSONObject: requestDictionary, options: [])
        let request = NSMutableURLRequest(url: URL(string: service)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        request.httpMethod = "POST"
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, resp, err) in
            if let data = data, let json = try! JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print(json)
                let results = (json["results"] as? [[String: Any]])
                if let first = results?.first, let alternatives = first["alternatives"] as? [[String: Any]] {
                    if let alternativesFirst = alternatives.first, let str = alternativesFirst["transcript"] as? String {
                        DispatchQueue.main.async {
                            AudioRESTController.sharedInstance.delegate.doneAnalyze([str])
                        }
                    }
                }
            }
        })
        task.resume()
    }
}
