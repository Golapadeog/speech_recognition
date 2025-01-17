import Flutter
import UIKit
import Speech

@available(iOS 10.0, *)
public class SwiftSpeechRecognitionPlugin: NSObject, FlutterPlugin, SFSpeechRecognizerDelegate
{
  public static func register(with registrar: FlutterPluginRegistrar)
  {
    let channel = FlutterMethodChannel(name: "speech_recognition", binaryMessenger: registrar.messenger())
    let instance = SwiftSpeechRecognitionPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var speechRecognizer: SFSpeechRecognizer?

  private var speechChannel: FlutterMethodChannel?

  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

  private var recognitionTask: SFSpeechRecognitionTask?

  private let audioEngine = AVAudioEngine()

  init(channel:FlutterMethodChannel)
  {
    speechChannel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
  {
    switch(call.method)
    {
      case "speech.activate":
        self.activateRecognition(result: result)
      case "speech.listen":
        self.startRecognition(lang: call.arguments as! String, result: result)
      case "speech.cancel":
        self.cancelRecognition(result: result)
      case "speech.stop":
        self.stopRecognition(result: result)
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  private func activateRecognition(result: @escaping FlutterResult)
  {
    SFSpeechRecognizer.requestAuthorization
    {
        authStatus in
        
        OperationQueue.main.addOperation
        {
            switch authStatus
            {
                case .authorized:
                  result(true)
                  self.speechChannel?.invokeMethod("speech.onCurrentLocale", arguments: "\(Locale.current.identifier)")

                case .denied:
                  result(false)

                case .restricted:
                  result(false)

                case .notDetermined:
                  result(false)
            }
            
            print("SFSpeechRecognizer.requestAuthorization \(authStatus.rawValue)")
        }
    }
  }

  private func startRecognition(lang: String, result: FlutterResult)
  {
    print("startRecognition...")
    if audioEngine.isRunning
    {
      audioEngine.stop()
      recognitionRequest?.endAudio()
      result(false)
    } 
    else
    {
      try! start(lang: lang)
      result(true)
    }
  }

  private func cancelRecognition(result: FlutterResult?)
  {
    if let recognitionTask = recognitionTask
    {
      recognitionTask.cancel()
      self.recognitionTask = nil
      if let r = result
      {
        r(false)
      }
    }
  }

  private func stopRecognition(result: FlutterResult)
  {
    if audioEngine.isRunning
    {
      audioEngine.stop()
      recognitionRequest?.endAudio()
    }
    result(false)
  }

  private func start(lang: String) throws
  {
    cancelRecognition(result: nil)

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSession.Category.record, mode: .default)
    try audioSession.setMode(AVAudioSession.Mode.measurement)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    let inputNode = audioEngine.inputNode
    
    guard let recognitionRequest = recognitionRequest else
    {
      fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
    }

    recognitionRequest.shouldReportPartialResults = true

    if let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: lang))
    {
      speechRecognizer.delegate = self
      
      recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest)
      {
          result, error in
          
          var isFinal = false
          
          if let result = result
          {
              print("Speech : \(result.bestTranscription.formattedString)")
              self.speechChannel?.invokeMethod("speech.onSpeech", arguments: result.bestTranscription.formattedString)
              isFinal = result.isFinal
              if isFinal
              {
                  self.speechChannel?.invokeMethod("speech.onRecognitionComplete", arguments: result.bestTranscription.formattedString)
              }
          }
          
          if error != nil || isFinal
          {
              self.audioEngine.stop()
              inputNode.removeTap(onBus: 0)
              self.recognitionRequest = nil
              self.recognitionTask = nil
          }
      }
      
      let recognitionFormat = inputNode.outputFormat(forBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: recognitionFormat)
      {
          (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
          self.recognitionRequest?.append(buffer)
      }
      
      audioEngine.prepare()
      try audioEngine.start()
      
      speechChannel?.invokeMethod("speech.onRecognitionStarted", arguments: nil)
    }
    else
    {
        fatalError("Unable to created a speechRecognizer object for language \(lang)")
    }
  }

  public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool)
  {
    speechChannel?.invokeMethod("speech.onSpeechAvailability", arguments: available)
  }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String
{
	return input.rawValue
}
