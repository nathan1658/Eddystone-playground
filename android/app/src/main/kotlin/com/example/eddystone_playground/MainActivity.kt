package com.example.eddystone_playground

import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.pm.PackageManager
import android.os.ParcelUuid
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "eddystone_playground/beacon_advertiser"
    private val eddystoneServiceUuid =
        ParcelUuid(UUID.fromString("0000FEAA-0000-1000-8000-00805F9B34FB"))
    private var advertiseCallback: AdvertiseCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "startIBeacon" -> startIBeacon(call, result)
                "startEddystoneUid" -> startEddystoneUid(call, result)
                "startEddystoneUrl" -> startEddystoneUrl(call, result)
                "stop" -> {
                    stopAdvertising()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun capabilities(): Map<String, Any> {
        val hasBle = packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
        val advertiserAvailable = try {
            bluetoothManager()?.adapter?.bluetoothLeAdvertiser != null
        } catch (_: SecurityException) {
            false
        }
        val supported = hasBle && advertiserAvailable
        return mapOf(
            "isSupported" to supported,
            "iBeacon" to supported,
            "eddystone" to supported,
            "platform" to "android",
            "message" to if (supported) {
                "Android BLE advertiser ready"
            } else {
                "BLE advertising is unavailable or Bluetooth is off"
            }
        )
    }

    private fun startIBeacon(call: MethodCall, result: MethodChannel.Result) {
        val uuidText = call.argument<String>("uuid")
        val major = call.argument<Int>("major")
        val minor = call.argument<Int>("minor")
        val measuredPower = call.argument<Int>("measuredPower") ?: -59
        if (uuidText == null || major == null || minor == null) {
            result.error("bad_args", "Missing iBeacon UUID, major, or minor", null)
            return
        }

        val uuid = try {
            UUID.fromString(uuidText)
        } catch (_: IllegalArgumentException) {
            result.error("bad_uuid", "Invalid UUID", null)
            return
        }
        if (major !in 0..65535 || minor !in 0..65535) {
            result.error("bad_args", "Major and minor must be 0-65535", null)
            return
        }

        val manufacturerData = ByteArray(23)
        manufacturerData[0] = 0x02.toByte()
        manufacturerData[1] = 0x15.toByte()
        val uuidBytes = ByteBuffer.allocate(16)
            .putLong(uuid.mostSignificantBits)
            .putLong(uuid.leastSignificantBits)
            .array()
        uuidBytes.copyInto(manufacturerData, destinationOffset = 2)
        manufacturerData[18] = ((major shr 8) and 0xff).toByte()
        manufacturerData[19] = (major and 0xff).toByte()
        manufacturerData[20] = ((minor shr 8) and 0xff).toByte()
        manufacturerData[21] = (minor and 0xff).toByte()
        manufacturerData[22] = measuredPower.toByte()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addManufacturerData(0x004c, manufacturerData)
            .build()

        startAdvertising(data, result)
    }

    private fun startEddystoneUid(call: MethodCall, result: MethodChannel.Result) {
        val namespaceId = call.argument<String>("namespaceId")
        val instanceId = call.argument<String>("instanceId")
        val measuredPower = call.argument<Int>("measuredPower") ?: -59
        val namespaceBytes = namespaceId?.hexToBytes(expectedBytes = 10)
        val instanceBytes = instanceId?.hexToBytes(expectedBytes = 6)
        if (namespaceBytes == null || instanceBytes == null) {
            result.error("bad_args", "Namespace must be 10 bytes and instance 6 bytes", null)
            return
        }

        val serviceData = ByteArray(20)
        serviceData[0] = 0x00.toByte()
        serviceData[1] = measuredPower.toByte()
        namespaceBytes.copyInto(serviceData, destinationOffset = 2)
        instanceBytes.copyInto(serviceData, destinationOffset = 12)
        serviceData[18] = 0x00.toByte()
        serviceData[19] = 0x00.toByte()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(eddystoneServiceUuid)
            .addServiceData(eddystoneServiceUuid, serviceData)
            .build()

        startAdvertising(data, result)
    }

    private fun startEddystoneUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val measuredPower = call.argument<Int>("measuredPower") ?: -59
        val encodedUrl = encodeEddystoneUrl(url)
        if (encodedUrl == null) {
            result.error("bad_url", "URL is invalid or too long for an Eddystone URL frame", null)
            return
        }

        val serviceData = ByteArray(2 + encodedUrl.size)
        serviceData[0] = 0x10.toByte()
        serviceData[1] = measuredPower.toByte()
        encodedUrl.copyInto(serviceData, destinationOffset = 2)

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(eddystoneServiceUuid)
            .addServiceData(eddystoneServiceUuid, serviceData)
            .build()

        startAdvertising(data, result)
    }

    private fun startAdvertising(data: AdvertiseData, result: MethodChannel.Result) {
        val advertiser = try {
            bluetoothManager()?.adapter?.bluetoothLeAdvertiser
        } catch (error: SecurityException) {
            result.error("permission", "Missing Bluetooth advertise permission", error.message)
            return
        }
        if (advertiser == null) {
            result.error("unsupported", "BLE advertiser is unavailable", null)
            return
        }

        stopAdvertising()
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                result.success(null)
            }

            override fun onStartFailure(errorCode: Int) {
                advertiseCallback = null
                result.error("advertise_failed", advertiseError(errorCode), errorCode)
            }
        }
        advertiseCallback = callback
        try {
            advertiser.startAdvertising(settings, data, callback)
        } catch (error: SecurityException) {
            advertiseCallback = null
            result.error("permission", "Missing Bluetooth advertise permission", error.message)
        } catch (error: IllegalArgumentException) {
            advertiseCallback = null
            result.error("bad_payload", error.message, null)
        }
    }

    private fun stopAdvertising() {
        val callback = advertiseCallback ?: return
        try {
            bluetoothManager()?.adapter?.bluetoothLeAdvertiser?.stopAdvertising(callback)
        } catch (_: SecurityException) {
            // The next start call will surface the permission state to Flutter.
        }
        advertiseCallback = null
    }

    private fun bluetoothManager(): BluetoothManager? {
        return getSystemService(BluetoothManager::class.java)
    }

    private fun advertiseError(errorCode: Int): String {
        return when (errorCode) {
            AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED -> "Advertising already started"
            AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE -> "Advertising packet is too large"
            AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "BLE advertising is unsupported"
            AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR -> "Android reported an internal advertiser error"
            AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers are active"
            else -> "Advertising failed with code $errorCode"
        }
    }

    private fun String.hexToBytes(expectedBytes: Int): ByteArray? {
        val cleaned = trim().lowercase(Locale.US)
        if (cleaned.length != expectedBytes * 2 || !cleaned.matches(Regex("^[0-9a-f]+$"))) {
            return null
        }
        return ByteArray(expectedBytes) { index ->
            cleaned.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
    }

    private fun encodeEddystoneUrl(url: String?): ByteArray? {
        if (url == null) return null
        val prefixes = listOf(
            "http://www." to 0x00,
            "https://www." to 0x01,
            "http://" to 0x02,
            "https://" to 0x03,
        )
        val expansions = listOf(
            ".com/" to 0x00,
            ".org/" to 0x01,
            ".edu/" to 0x02,
            ".net/" to 0x03,
            ".info/" to 0x04,
            ".biz/" to 0x05,
            ".gov/" to 0x06,
            ".com" to 0x07,
            ".org" to 0x08,
            ".edu" to 0x09,
            ".net" to 0x0a,
            ".info" to 0x0b,
            ".biz" to 0x0c,
            ".gov" to 0x0d,
        )
        val prefix = prefixes.firstOrNull { url.startsWith(it.first, ignoreCase = true) }
            ?: return null
        val bytes = mutableListOf(prefix.second.toByte())
        var index = prefix.first.length
        while (index < url.length) {
            val expansion = expansions.firstOrNull {
                url.regionMatches(index, it.first, 0, it.first.length, ignoreCase = true)
            }
            if (expansion != null) {
                bytes.add(expansion.second.toByte())
                index += expansion.first.length
                continue
            }
            val charCode = url[index].code
            if (charCode !in 32..126) {
                return null
            }
            bytes.add(charCode.toByte())
            index += 1
        }
        if (bytes.size > 18) {
            return null
        }
        return bytes.toByteArray()
    }
}
