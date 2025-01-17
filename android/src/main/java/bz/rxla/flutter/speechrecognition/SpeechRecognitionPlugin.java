package bz.rxla.flutter.speechrecognition;

import android.app.Activity;
import android.content.Intent;
import android.content.Context;
import android.provider.Settings;
import android.net.Uri;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.util.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.util.ArrayList;
import java.util.Locale;

/**
 * SpeechRecognitionPlugin
 */
public class SpeechRecognitionPlugin implements MethodCallHandler, RecognitionListener 
{
    private static final String LOG_TAG = "SpeechRecognitionPlugin";
    private SpeechRecognizer speech;
    private MethodChannel speechChannel;
    private String transcription = "";
    private Intent recognizerIntent;
    private Activity activity;
    private final Registrar registrar;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) 
    {
        if(registrar.activity() != null)
        {
            final MethodChannel channel = new MethodChannel(registrar.messenger(), "speech_recognition");
            channel.setMethodCallHandler(new SpeechRecognitionPlugin(registrar, channel));
        }
    }

    private SpeechRecognitionPlugin(Registrar registrar, MethodChannel channel) 
    {
        this.speechChannel = channel;
        this.speechChannel.setMethodCallHandler(this);
        this.activity = registrar.activity();
        this.registrar = registrar;

        speech = SpeechRecognizer.createSpeechRecognizer(registrar.activity().getApplicationContext());
        speech.setRecognitionListener(this);

        recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.getApplicationContext().getPackageName());
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) 
    {
        switch(call.method) 
        {
            case "speech.activate":
                // FIXME => Dummy activation verification : we assume that speech recognition permission
                // is declared in the manifest and accepted during installation ( AndroidSDK 21- )
                //Locale locale = activity.getResources().getConfiguration().locale;
                //speechChannel.invokeMethod("speech.onCurrentLocale", locale.toString());
                //Log.d(LOG_TAG, "Current Locale : " + locale.toString());
                result.success(true);
                break;
            case "speech.listen":
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, call.arguments.toString());
                speech.startListening(recognizerIntent);
                result.success(true);
                break;
            case "speech.openGoogleSettings":
                Intent intent = new Intent();
                intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                Uri uri = Uri.fromParts("package", "com.google.android.googlequicksearchbox", null);
                intent.setData(uri);
                registrar.activity().startActivity(intent);
                result.success(true);
                break;
            case "speech.cancel":
                speech.cancel();
                result.success(false);
                break;
            case "speech.stop":
                speech.stopListening();
                result.success(true);
                break;
            case "speech.destroy":
                speech.cancel();
                speech.destroy();
                result.success(true);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onReadyForSpeech(Bundle params) 
    {
        //Log.d(LOG_TAG, "onReadyForSpeech");
        speechChannel.invokeMethod("speech.onSpeechAvailability", true);
    }

    @Override
    public void onBeginningOfSpeech() 
    {
        //Log.d(LOG_TAG, "onRecognitionStarted");
        transcription = "";
        speechChannel.invokeMethod("speech.onRecognitionStarted", null);
    }

    @Override
    public void onRmsChanged(float rmsdB) 
    {
        //Log.d(LOG_TAG, "onRmsChanged : " + rmsdB);
    }

    @Override
    public void onBufferReceived(byte[] buffer) 
    {
        //Log.d(LOG_TAG, "onBufferReceived");
    }

    @Override
    public void onEndOfSpeech() 
    {
        //Log.d(LOG_TAG, "onEndOfSpeech:" + transcription);
        //speechChannel.invokeMethod("speech.onRecognitionComplete", transcription);
    }

    @Override
    public void onError(int error) 
    {
        //Log.d(LOG_TAG, "onError : " + error);
        //speechChannel.invokeMethod("speech.onSpeechAvailability", false);
        speechChannel.invokeMethod("speech.onError", error);
    }

    @Override
    public void onPartialResults(Bundle partialResults) 
    {
        //Log.d(LOG_TAG, "onPartialResults...");
        ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if(matches != null) 
        {
            transcription = matches.get(0);
        }
        sendTranscription(false);
    }

    @Override
    public void onEvent(int eventType, Bundle params) 
    {
        Log.d(LOG_TAG, "onEvent : " + eventType);
    }

    @Override
    public void onResults(Bundle results) 
    {
        //Log.d(LOG_TAG, "onResults...");

        ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if(matches != null) 
        {
            /*for(String s : matches) 
            {
                Log.d(LOG_TAG, "matches: " + s);                
            } */
            transcription = matches.get(0);
            //Log.d(LOG_TAG, "onResults -> " + transcription);
            sendTranscription(true);
        }

        sendTranscription(false);
    }

    private void sendTranscription(boolean isFinal) 
    {
        speechChannel.invokeMethod(isFinal ? "speech.onRecognitionComplete" : "speech.onSpeech", transcription);
    }
}
