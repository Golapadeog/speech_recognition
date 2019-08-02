import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';

enum SpeechErrorEnum
{
	ERROR_OK,                       // 0
	ERROR_NETWORK_TIMEOUT,          // 1
	ERROR_NETWORK,                  // 2
	ERROR_AUDIO,                    // 3
	ERROR_SERVER,                   // 4
	ERROR_CLIENT,                   // 5
	ERROR_SPEECH_TIMEOUT,           // 6
	ERROR_NO_MATCH,                 // 7
	ERROR_RECOGNIZER_BUSY,          // 8
	ERROR_INSUFFICIENT_PERMISSIONS, // 9
}

typedef void AvailabilityHandler(bool result);
typedef void StringResultHandler(String text);
typedef void ErrorHandler(SpeechErrorEnum error);

/// the channel to control the speech recognition
class SpeechRecognition 
{
  static const MethodChannel _channel = const MethodChannel('speech_recognition');
  static final SpeechRecognition _speech = new SpeechRecognition._internal();
  factory SpeechRecognition() => _speech;
  SpeechRecognition._internal() 
  {
    _channel.setMethodCallHandler(_platformCallHandler);
  }

  AvailabilityHandler availabilityHandler;
  StringResultHandler recognitionResultHandler;
  VoidCallback recognitionStartedHandler;
  StringResultHandler recognitionCompleteHandler;  
  ErrorHandler errorHandler;

  Future activate() => _channel.invokeMethod("speech.activate");
  Future listen({String locale}) => _channel.invokeMethod("speech.listen", locale);
  Future cancel() => _channel.invokeMethod("speech.cancel");
  Future stop() => _channel.invokeMethod("speech.stop");

  void setAvailabilityHandler(AvailabilityHandler handler) => availabilityHandler = handler;
  void setRecognitionResultHandler(StringResultHandler handler) => recognitionResultHandler = handler;
  void setRecognitionStartedHandler(VoidCallback handler) => recognitionStartedHandler = handler;
  void setRecognitionCompleteHandler(StringResultHandler handler) => recognitionCompleteHandler = handler;
  void setErrorHandler(ErrorHandler handler) => errorHandler = handler;

  Future _platformCallHandler(MethodCall call) async 
  {
    //print("_platformCallHandler call ${call.method} ${call.arguments}");

    switch (call.method) 
    {
      case "speech.onSpeechAvailability":
        availabilityHandler(call.arguments);
        break;

      case "speech.onSpeech":
        recognitionResultHandler(call.arguments);
        break;

      case "speech.onRecognitionStarted":
        recognitionStartedHandler();
        break;

      case "speech.onRecognitionComplete":
        recognitionCompleteHandler(call.arguments);
        break;

      case "speech.onError":
        errorHandler(SpeechErrorEnum.values[call.arguments]);
        break;

      default:
        print('Unknowm method ${call.method} ');
    }
  }
}
