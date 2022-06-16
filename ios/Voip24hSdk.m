#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(Voip24hSdk, RCTEventEmitter)

RCT_EXTERN_METHOD(initializeModule)

RCT_EXTERN_METHOD(registerSipAccount:(NSString *)username
                  withPassword:(NSString *)password
                  withDomain:(NSString *)domain)

RCT_EXTERN_METHOD(refreshRegisterSipAccount)

RCT_EXTERN_METHOD(unregisterSipAccount)

//RCT_EXTERN_METHOD(bluetoothAudio:(RCTPromiseResolveBlock)resolve
//                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(hangup)

RCT_EXTERN_METHOD(acceptCall)

RCT_EXTERN_METHOD(decline)

RCT_EXTERN_METHOD(pause)

RCT_EXTERN_METHOD(resume)

RCT_EXTERN_METHOD(transfer:(NSString *)recipient)

//RCT_EXTERN_METHOD(loudAudio:(RCTPromiseResolveBlock)resolve
//                  withRejecter:(RCTPromiseRejectBlock)reject)
//
//RCT_EXTERN_METHOD(micEnabled:(RCTPromiseResolveBlock)resolve
//                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(call:(NSString *)recipient)

//RCT_EXTERN_METHOD(phoneAudio:(RCTPromiseResolveBlock)resolve
//                  withRejecter:(RCTPromiseRejectBlock)reject)
//
//RCT_EXTERN_METHOD(scanAudioDevices:(RCTPromiseResolveBlock)resolve
//                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(sendDtmf:(NSString *)dtmf)

RCT_EXTERN_METHOD(toggleMic:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(toggleSpeaker:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(getMissedCalls:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getSipRegistrationState:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getCallId:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
@end
