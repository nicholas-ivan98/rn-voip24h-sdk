// Voip24hSdkModule.java
package com.reactlibrary

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import org.linphone.core.*


class Voip24hSdkModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private lateinit var mCore: Core
    private val coreListener = object : CoreListenerStub() {
        override fun onAccountRegistrationStateChanged(
            core: Core,
            account: Account,
            state: RegistrationState?,
            message: String
        ) {
          sendEvent("onAccountRegistrationStateChanged", createParams("registrationState" to (state?.name ?: ""), "message" to message))
        }

        override fun onCallStateChanged(
            core: Core,
            call: Call,
            state: Call.State?,
            message: String
        ) {
            when (state) {
                Call.State.IncomingReceived -> {
                    Log.d(TAG, "IncomingReceived")
                    val callee = call.remoteAddress.username ?: ""
                    sendEvent("onIncomingReceived", createParams("callee" to callee))
                }
                Call.State.OutgoingInit -> {
                    // First state an outgoing call will go through
                    Log.d(TAG, "OutgoingInit")
                    sendEvent("onOutgoingInit", null)
                }
                Call.State.OutgoingProgress -> {
                    // First state an outgoing call will go through
                    Log.d(TAG, "OutgoingProgress")
                    val callId = call.callLog.callId ?: ""
                    sendEvent("onOutgoingProgress", createParams("callId" to callId))
                }
                Call.State.OutgoingRinging -> {
                    // Once remote accepts, ringing will commence (180 response)
                    Log.d(TAG, "OutgoingRinging")
                    val callId = call.callLog.callId ?: ""
                    sendEvent("onOutgoingRinging", createParams("callId" to callId))
                }
                Call.State.Connected -> {
                    Log.d(TAG, "Connected")
                }
                Call.State.StreamsRunning -> {
                    // This state indicates the call is active.
                    // You may reach this state multiple times, for example after a pause/resume
                    // or after the ICE negotiation completes
                    // Wait for the call to be connected before allowing a call update
                    Log.d(TAG, "StreamsRunning")
                    val callId = call.callLog.callId ?: ""
                    val callee = call.remoteAddress.username ?: ""
                    sendEvent("onStreamsRunning", createParams("callId" to callId, "callee" to callee))
                }
                Call.State.Paused -> {
                    Log.d(TAG, "Paused")
                    sendEvent("onPaused", null)
                }
                Call.State.PausedByRemote -> {
                    Log.d(TAG, "PausedByRemote")
                    sendEvent("onPausedByRemote", null)
                }
                Call.State.Updating -> {
                    // When we request a call update, for example when toggling video
                    Log.d(TAG, "Updating")
                }
                Call.State.UpdatedByRemote -> {
                    Log.d(TAG, "UpdatedByRemote")
                }
                Call.State.Released -> {
                    Log.d(TAG, "Released")
                    if(isMissed(call.callLog)) {
                        Log.d(TAG,"Missed")
                        val callee = call.remoteAddress.username ?: ""
                        val totalMissed = core.missedCallsCount.toString()
                        sendEvent("onMissed", createParams("callee" to callee, "totalMissed" to totalMissed))
                    } else {
                        Log.d(TAG, "Released")
                        sendEvent("onReleased", null)
                    }
                }
                Call.State.Error -> {
                    Log.d(TAG, "Error")
                    sendEvent("onError", createParams("message" to message))
                }
                else -> {
                    Log.d(TAG, "Nothing")
                }
            }
        }
    }

    companion object {
        private const val TAG = "Voip24hSdkModule"
    }

    override fun getName(): String {
        return "Voip24hSdk"
    }

    private fun sendEvent(eventName: String, params: WritableMap?) {
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    private fun createParams(vararg params: Pair<String, String>) : WritableMap {
        return Arguments.createMap().apply {
            params.forEach {
                putString(it.first, it.second)
            }
        }
    }

    @ReactMethod
    fun initializeModule() {
        val factory = Factory.instance()
        mCore = factory.createCore(null, null, reactContext.applicationContext)
        mCore.start()
        mCore.addListener(coreListener)
    }

    @ReactMethod
    fun registerSipAccount(username: String, password: String, domain: String) {
        val transportType = TransportType.Udp

        // To configure a SIP account, we need an Account object and an AuthInfo object
        // The first one is how to connect to the proxy server, the second one stores the credentials

        // The auth info can be created from the Factory as it's only a data class
        // userID is set to null as it's the same as the username in our case
        // ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
        // The realm will be determined automatically from the first register, as well as the algorithm
        val authInfo =
            Factory.instance().createAuthInfo(username, null, password, null, null, domain, null)

        // Account object replaces deprecated ProxyConfig object
        // Account object is configured through an AccountParams object that we can obtain from the Core
        val accountParams = mCore.createAccountParams()

        // A SIP account is identified by an identity address that we can construct from the username and domain
        val identity = Factory.instance().createAddress("sip:$username@$domain")
        accountParams.identityAddress = identity

        // We also need to configure where the proxy server is located
        val address = Factory.instance().createAddress("sip:$domain")
        // We use the Address object to easily set the transport protocol
        address?.transport = transportType
        accountParams.serverAddress = address
        // And we ensure the account will start the registration process
        accountParams.isRegisterEnabled = true

        // Now that our AccountParams is configured, we can create the Account object
        val account = mCore.createAccount(accountParams)

        // Now let's add our objects to the Core
        mCore.addAuthInfo(authInfo)
        mCore.addAccount(account)

        // Also set the newly added account as default
        mCore.defaultAccount = account
    }

    @ReactMethod
    fun refreshRegisterSipAccount() {
        mCore.refreshRegisters()
    }

    @ReactMethod
    fun unregisterSipAccount() {
        // Here we will disable the registration of our Account
        val account = mCore.defaultAccount
        account ?: return
        val params = account.params
        // Returned params object is const, so to make changes we first need to clone it
        val clonedParams = params.clone()
        // Now let's make our changes
        clonedParams.isRegisterEnabled = false
        // And apply them
        account.params = clonedParams
        mCore.clearProxyConfig()
        deleteSipAccount()
    }

    private fun deleteSipAccount() {
        // To completely remove an Account
        val account = mCore.defaultAccount
        account ?: return
        mCore.removeAccount(account)

        // To remove all accounts use
        mCore.clearAccounts()

        // Same for auth info
        mCore.clearAllAuthInfo()
    }

    @ReactMethod
    fun call(recipient: String) {
        Log.d(TAG, "Try to call")
        // As for everything we need to get the SIP URI of the remote and convert it to an Address
        val domain = mCore.defaultAccount?.params?.domain
        Log.d(TAG, "Domain: $domain")
        if (domain == null) {
            Log.d(TAG, "Outgoing call failure: can't create sip uri")
            return
        }
        val remoteAddress = Factory.instance().createAddress("sip:$recipient@$domain")
        if (remoteAddress == null) {
            Log.d(TAG, "Invalid SIP URI")
            return
        } else {
            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            val params = mCore.createCallParams(null)
            params ?: return // Same for params

            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params.mediaEncryption = MediaEncryption.None
            // If we wanted to start the call with video directly
            //params.enableVideo(true)

            // Finally we start the call
            mCore.inviteAddressWithParams(remoteAddress, params)
        }
    }

    @ReactMethod
    fun hangup() {
        Log.d(TAG, "Trying to hang up")
        try {
            if (mCore.callsNb == 0) return
            val coreCall = mCore.currentCall ?: mCore.calls.firstOrNull()
            coreCall?.terminate()
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun acceptCall() {
        Log.d(TAG, "Try to accept call")
        try {
            mCore.currentCall?.accept()
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun decline() {
        Log.d(TAG, "Try to accept call")
        try {
            mCore.currentCall?.terminate()
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun pause() {
        Log.d(TAG, "Try to pause")
        try {
            if(mCore.callsNb == 0) return
            val coreCall = mCore.currentCall ?: mCore.calls.firstOrNull()
            coreCall?.pause()
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun resume() {
        Log.d(TAG, "Try to resume")
        try {
            if(mCore.callsNb == 0) return
            val coreCall = mCore.currentCall ?: mCore.calls.firstOrNull()
            coreCall?.resume()
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun transfer(recipient: String) {
        Log.d(TAG, "Try to transfer")
        try {
            if(mCore.callsNb == 0) return
            val domain = mCore.defaultAccount?.params?.domain
            Log.d(TAG, "Domain: $domain")
            if (domain == null) {
                Log.d(TAG, "Outgoing call failure: can't create sip uri")
                return
            }
            val address = mCore.interpretUrl("sip:$recipient@$domain") ?: return
            val coreCall = mCore.currentCall ?: mCore.calls.firstOrNull()
            coreCall?.transferTo(address)
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun sendDtmf(dtmf: String) {
        try {
            mCore.currentCall?.sendDtmf(dtmf.first())
        } catch (e: Exception) {
            Log.d(TAG, e.message.toString())
        }
    }

    @ReactMethod
    fun toggleMic(promise: Promise) {
        try {
            mCore.isMicEnabled = !mCore.isMicEnabled
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject(e)
        }
    }

    @ReactMethod
    fun toggleSpeaker(promise: Promise) {
        try {
            val currentAudioDevice = mCore.currentCall?.outputAudioDevice
            val speakerEnabled = currentAudioDevice?.type == AudioDevice.Type.Speaker
            for (audioDevice in mCore.audioDevices) {
                if (speakerEnabled && audioDevice.type == AudioDevice.Type.Earpiece) {
                    mCore.currentCall?.outputAudioDevice = audioDevice
                    return
                } else if (!speakerEnabled && audioDevice.type == AudioDevice.Type.Speaker) {
                    mCore.currentCall?.outputAudioDevice = audioDevice
                    return
                }
            }
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject(e)
        }
    }

    @ReactMethod
    fun getCallId(promise: Promise) {
        mCore.currentCall?.callLog?.callId?.let {
            promise.resolve(it)
        } ?: kotlin.run {
            promise.reject(Throwable("Call ID not found"))
        }
    }

    @ReactMethod
    fun getMissedCalls(promise: Promise) {
        promise.resolve(mCore.missedCallsCount)
    }

    @ReactMethod
    fun getSipRegistrationState(promise: Promise) {
        mCore.defaultAccount?.state?.name?.let {
            promise.resolve(it)
        } ?: kotlin.run {
            promise.reject(Throwable("Register state not found"))
        }
    }

    private fun isMissed(callLog: CallLog?): Boolean {
        return (callLog?.dir == Call.Dir.Incoming && callLog.status == Call.Status.Missed)
    }

    @ReactMethod
    fun addListener(eventName: String?) {
    }

    @ReactMethod
    fun removeListeners(count: Int?) {
    }
}