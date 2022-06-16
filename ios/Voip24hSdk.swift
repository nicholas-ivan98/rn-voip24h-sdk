//
//  Voip24hSdk.swift
//  Voip24hSdk
//
//  Created by Phát Nguyễn on 08/06/2022.
//  Copyright © 2022 Facebook. All rights reserved.
//

import linphonesw
import React
import Foundation
import UIKit

@objc(Voip24hSdk)
class Voip24hSdk: RCTEventEmitter {
    private var mCore: Core!
    private var mRegistrationDelegate : CoreDelegate!
    
    //    private var bluetoothMic: AudioDevice?
    //    private var bluetoothSpeaker: AudioDevice?
    //    private var earpiece: AudioDevice?
    //    private var loudMic: AudioDevice?
    //    private var loudSpeaker: AudioDevice?
    //    private var microphone: AudioDevice?
    private var isSpeakerEnabled: Bool = false
    
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    override func supportedEvents() -> [String]! {
        return ["onAccountRegistrationStateChanged", "onIncomingReceived", "onOutgoingInit", "onOutgoingProgress", "onOutgoingRinging", "onStreamsRunning", "onPaused", "onPausedByRemote", "onMissed", "onReleased", "onError"]
    }
    
    private func deleteSipAccount() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)
            
            // To remove all accounts use
            mCore.clearAccounts()
            
            // Same for auth info
            mCore.clearAllAuthInfo()
        }
    }
    
    @objc(initializeModule)
    func initializeModule() {
        do {
            LoggingService.Instance.logLevel = LogLevel.Debug
            
            try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            try? mCore.start()
            
            // Create a Core listener to listen for the callback we need
            // In this case, we want to know about the account registration status
            mRegistrationDelegate = CoreDelegateStub(
                onCallStateChanged: {(
                    core: Core,
                    call: Call,
                    state: Call.State?,
                    message: String
                ) in
                    switch (state) {
                    case .IncomingReceived:
                        // Immediately hang up when we receive a call. There's nothing inherently wrong with this
                        // but we don't need it right now, so better to leave it deactivated.
                        // try! call.terminate()
                        NSLog("IncomingReceived")
                        let callee = call.remoteAddress?.username ?? ""
                        self.sendEvent(withName: "onIncomingReceived", body: ["callee": callee])
                    case .OutgoingInit:
                        // First state an outgoing call will go through
                        NSLog("OutgoingInit")
                        self.sendEvent(withName: "onOutgoingInit", body: nil)
                    case .OutgoingProgress:
                        // First state an outgoing call will go through
                        NSLog("OutgoingProgress")
                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(withName: "onOutgoingProgress", body: ["callId": callId])
                    case .OutgoingRinging:
                        // Once remote accepts, ringing will commence (180 response)
                        NSLog("OutgoingRinging")
                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(withName: "onOutgoingRinging", body: ["callId": callId])
                    case .Connected:
                        NSLog("Connected")
                    case .StreamsRunning:
                        // This state indicates the call is active.
                        // You may reach this state multiple times, for example after a pause/resume
                        // or after the ICE negotiation completes
                        // Wait for the call to be connected before allowing a call update
                        NSLog("StreamsRunning")
                        let callId = call.callLog?.callId ?? ""
                        let callee = call.remoteAddress?.username ?? ""
                        self.sendEvent(withName: "onStreamsRunning", body: ["callId": callId, "callee": callee])
                    case .Paused:
                        NSLog("Paused")
                        self.sendEvent(withName: "onPaused", body: nil)
                    case .PausedByRemote:
                        NSLog("PausedByRemote")
                        self.sendEvent(withName: "onPausedByRemote", body: nil)
                    case .Updating:
                        // When we request a call update, for example when toggling video
                        NSLog("Updating")
                    case .UpdatedByRemote:
                        NSLog("UpdatedByRemote")
                    case .Released:
                        if(self.isMissed(callLog: call.callLog)) {
                            NSLog("Missed")
                            let callee = call.remoteAddress?.username ?? ""
                            let totalMissed = core.missedCallsCount
                            self.sendEvent(withName: "onMissed", body: ["callee": callee, "totalMissed": totalMissed])
                        } else {
                            NSLog("Released", "")
                            self.sendEvent(withName: "onReleased", body: nil)
                        }
                    case .Error:
                        NSLog("Error")
                        self.sendEvent(withName: "onError", body: ["message": message])
                    default:
                        NSLog("Nothing")
                    }
                },
                // onAudioDevicesListUpdated: { (core: Core) in
                // self.sendEvent(withName: "AudioDevicesChanged", body: "")
                // },
                onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
                    self.sendEvent(withName: "onAccountRegistrationStateChanged", body: ["registrationState": RegisterSipState.allCases[state.rawValue].rawValue, "message": message])
                }
            )
            mCore.addDelegate(delegate: mRegistrationDelegate)
        }
    }
    
    private func isMissed(callLog: CallLog?) -> Bool {
        return (callLog?.dir == Call.Dir.Incoming && callLog?.status == Call.Status.Missed)
    }
    
    @objc(registerSipAccount:withPassword:withDomain:)
    func registerSipAccount(username: String, password: String, domain: String) {
        do {
            let transport = TransportType.Udp
            
            // To configure a SIP account, we need an Account object and an AuthInfo object
            // The first one is how to connect to the proxy server, the second one stores the credentials
            
            // The auth info can be created from the Factory as it's only a data class
            // userID is set to null as it's the same as the username in our case
            // ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
            // The realm will be determined automatically from the first register, as well as the algorithm
            let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: password, ha1: "", realm: "", domain: domain)
            
            // Account object replaces deprecated ProxyConfig object
            // Account object is configured through an AccountParams object that we can obtain from the Core
            let accountParams = try mCore.createAccountParams()
            
            // A SIP account is identified by an identity address that we can construct from the username and domain
            let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
            try! accountParams.setIdentityaddress(newValue: identity)
            
            // We also need to configure where the proxy server is located
            let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
            
            // We use the Address object to easily set the transport protocol
            try address.setTransport(newValue: transport)
            try accountParams.setServeraddress(newValue: address)
            // And we ensure the account will start the registration process
            accountParams.registerEnabled = true
            
            // Now that our AccountParams is configured, we can create the Account object
            let account = try mCore.createAccount(params: accountParams)
            
            // Now let's add our objects to the Core
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            // Also set the newly added account as default
            mCore.defaultAccount = account
            
            
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(unregisterSipAccount)
    func unregisterSipAccount() {
        // Here we will disable the registration of our Account
        NSLog("Try to unregister")
        if let account = mCore.defaultAccount {
            let params = account.params
            let clonedParams = params?.clone()
            clonedParams?.registerEnabled = false
            account.params = clonedParams
            mCore.clearProxyConfig()
            deleteSipAccount()
        }
    }
    
    @objc(refreshRegisterSipAccount)
    func refreshRegisterSipAccount() {
        mCore.refreshRegisters()
    }
    
    //    @objc(bluetoothAudio:withRejecter:)
    //    func bluetoothAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    //        if let mic = self.bluetoothMic {
    //            mCore.inputAudioDevice = mic
    //        }
    //
    //        if let speaker = self.bluetoothSpeaker {
    //            mCore.outputAudioDevice = speaker
    //        }
    //
    //        resolve(true)
    //    }
    
    @objc(call:)
    func call(recipient: String) {
        NSLog("Try to call out")
        do {
            // As for everything we need to get the SIP URI of the remote and convert it sto an Address
            let domain: String? = mCore.defaultAccount?.params?.domain
            NSLog("Domain: %@", domain ?? "")
            if (domain == nil) {
                return NSLog("Outgoing call failure: can't create sip uri")
            }
            let sipUri = String("sip:" + recipient + "@" + domain!)
            
            NSLog("Sip URI: %@", sipUri)
            
            let remoteAddress = try Factory.Instance.createAddress(addr: sipUri)
            
            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            let params = try mCore.createCallParams(call: nil)
            
            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params.mediaEncryption = MediaEncryption.None
            // If we wanted to start the call with video directly
            //params.videoEnabled = true
            
            // Finally we start the call
            let _ = mCore.inviteAddressWithParams(addr: remoteAddress, params: params)
            
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(hangup)
    func hangup() {
        NSLog("Trying to hang up")
        do {
            
            if (mCore.callsNb == 0) { return }
            
            // If the call state isn't paused, we can get it using core.currentCall
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if(coreCall == nil) {
                return
            }
            
            if(coreCall!.state == Call.State.IncomingReceived) {
                decline()
                return
            }
            
            // Terminating a call is quite simple
            if let call = coreCall {
                try call.terminate()
            } else {
                NSLog("No call to terminate")
            }
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(decline)
    func decline() {
        NSLog("Try to decline")
        do {
            try mCore.currentCall?.decline(reason: Reason.Forbidden)
            // resolve(true)
        } catch {
            NSLog(error.localizedDescription)
            // reject("Call decline failed", "Call decline failed", error)
        }
    }
    
    @objc(acceptCall)
    func acceptCall() {
        NSLog("Try accept call")
        do {
            try mCore.currentCall?.accept()
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(pause)
    func pause() {
        NSLog("Try to pause")
        do {
            if (mCore.callsNb == 0) { return }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if let call = coreCall {
                try call.pause()
            } else {
                NSLog("No call to pause")
            }
            
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(resume)
    func resume() {
        NSLog("Try to resume")
        do {
            if (mCore.callsNb == 0) { return }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if let call = coreCall {
                try call.resume()
            } else {
                NSLog("No to call to resume")
            }
            
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    @objc(transfer:)
    func transfer(recipient: String) {
        NSLog("Try to transfer")
        do {
            if (mCore.callsNb == 0) { return }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            let domain: String? = mCore.defaultAccount?.params?.domain
            NSLog("Domain: %@", domain ?? "")
            if (domain == nil) {
                NSLog("Outgoing call failure: can't create sip uri")
                return
            }
            
            let address = mCore.interpretUrl(url: String("sip:\(recipient)@\(domain!)"))
            NSLog("Address: %@", String("sip:\(recipient)@\(domain!)"))
            if(address == nil) {
                NSLog("Outgoing call failure: can't create sip uri")
                return
            }
            
            if let call = coreCall {
                try call.transferTo(referTo: address!)
            } else {
                NSLog("No call to transfer")
            }
            
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    //    @objc(loudAudio:withRejecter:)
    //    func loudAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    //        if let mic = loudMic {
    //            mCore.inputAudioDevice = mic
    //        } else if let mic = self.microphone {
    //            mCore.inputAudioDevice = mic
    //        }
    //
    //        if let speaker = loudSpeaker {
    //            mCore.outputAudioDevice = speaker
    //        }
    //
    //        resolve(true)
    //    }
    
    //    @objc(micEnabled:withRejecter:)
    //    func micEnabled(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    //        resolve(mCore.micEnabled)
    //    }
    
    //    @objc(phoneAudio:withRejecter:)
    //    func phoneAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    //        if let mic = microphone {
    //            mCore.inputAudioDevice = mic
    //        }
    //
    //        if let speaker = earpiece {
    //            mCore.outputAudioDevice = speaker
    //        }
    //
    //        resolve(true)
    //    }
    
    //    @objc(scanAudioDevices:withRejecter:)
    //    func scanAudioDevices(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    //        microphone = nil
    //        earpiece = nil
    //        loudSpeaker = nil
    //        loudMic = nil
    //        bluetoothSpeaker = nil
    //        bluetoothMic = nil
    //
    //        for audioDevice in mCore.audioDevices {
    //            switch (audioDevice.type) {
    //            case .Microphone:
    //                microphone = audioDevice
    //            case .Earpiece:
    //                earpiece = audioDevice
    //            case .Speaker:
    //                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
    //                    loudSpeaker = audioDevice
    //                } else {
    //                    loudMic = audioDevice
    //                }
    //            case .Bluetooth:
    //                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
    //                    bluetoothSpeaker = audioDevice
    //                } else {
    //                    bluetoothMic = audioDevice
    //                }
    //            default:
    //                NSLog("Audio device not recognised.")
    //            }
    //        }
    //
    //        let options: NSDictionary = [
    //            "phone": earpiece != nil && microphone != nil,
    //            "bluetooth": bluetoothMic != nil || bluetoothSpeaker != nil,
    //            "loudspeaker": loudSpeaker != nil
    //        ]
    //
    //        var current = "phone"
    //        if (mCore.outputAudioDevice?.type == .Bluetooth || mCore.inputAudioDevice?.type == .Bluetooth) {
    //            current = "bluetooth"
    //        } else if (mCore.outputAudioDevice?.type == .Speaker) {
    //            current = "loudspeaker"
    //        }
    //
    //        let result: NSDictionary = [
    //            "current": current,
    //            "options": options
    //        ]
    //        resolve(result)
    //    }
    
    @objc(sendDtmf:)
    func sendDtmf(dtmf: String) {
        do {
            try mCore.currentCall?.sendDtmf(dtmf: dtmf.utf8CString[0])
        } catch {
            NSLog("DTMF not recognised", error.localizedDescription)
        }
    }
    
    @objc(toggleMic:withRejecter:)
    func toggleMic(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        mCore.micEnabled = !mCore.micEnabled
        resolve(mCore.micEnabled)
    }
    
    @objc(toggleSpeaker:withRejecter:)
    func toggleSpeaker(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        let currentAudioDevice = mCore.currentCall?.outputAudioDevice
        let speakerEnabled = currentAudioDevice?.type == AudioDeviceType.Speaker
        
        // We can get a list of all available audio devices using
        // Note that on tablets for example, there may be no Earpiece device
        for audioDevice in mCore.audioDevices {
            
            // For IOS, the Speaker is an exception, Linphone cannot differentiate Input and Output.
            // This means that the default output device, the earpiece, is paired with the default phone microphone.
            // Setting the output audio device to the microphone will redirect the sound to the earpiece.
            if (speakerEnabled && audioDevice.type == AudioDeviceType.Microphone) {
                mCore.currentCall?.outputAudioDevice = audioDevice
                isSpeakerEnabled = false
                return
            } else if (!speakerEnabled && audioDevice.type == AudioDeviceType.Speaker) {
                mCore.currentCall?.outputAudioDevice = audioDevice
                isSpeakerEnabled = true
                return
            }
            /* If we wanted to route the audio to a bluetooth headset
             else if (audioDevice.type == AudioDevice.Type.Bluetooth) {
             core.currentCall?.outputAudioDevice = audioDevice
             }*/
        }
        resolve(true)
    }
    
    @objc(getCallId:withRejecter:)
    func getCallId(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        let callId = mCore.currentCall?.callLog?.callId
        if (callId != nil && !callId!.isEmpty) {
            resolve(callId!)
        } else {
            reject("Call ID not found", "Call ID not found", nil)
        }
    }
    
    @objc(getSipRegistrationState:withRejecter:)
    func getSipRegistrationState(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        let state = mCore.defaultAccount?.state
        if(state != nil) {
            resolve(RegisterSipState.allCases[state!.rawValue].rawValue)
        } else {
            reject("Register state not found", "Register state not found", nil)
        }
    }
    
    @objc(getMissedCalls:withRejecter:)
    func getMissedCalls(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(mCore.missedCallsCount)
    }
}


public enum RegisterSipState : String, CaseIterable {
    /// Initial state for registrations.
    case None = "None"
    /// Registration is in progress.
    case Progress = "Progress"
    /// Registration is successful.
    case Ok = "Ok"
    /// Unregistration succeeded.
    case Cleared = "Cleared"
    /// Registration failed.
    case Failed = "Failed"
}
