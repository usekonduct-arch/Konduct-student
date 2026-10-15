package com.konduct.konduct

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * The channels the backend names in its pushes (functions/src/domain/notify.ts).
     * Money alerts each get a spoken clip (res/raw/voice_*.wav) on the alarm stream, so they are
     * heard with the ringer on silent or vibrate. A channel's sound is fixed once created, which
     * is why these have new ids rather than reusing the old konduct_payments chime channel.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val general = NotificationChannel("konduct_default", "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Messages from the Konduct team and account updates"
        }
        val alarm = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        fun voice(id: String, name: String, about: String, clip: String) =
            NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = about
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 150, 300)
                setSound(Uri.parse("android.resource://$packageName/raw/$clip"), alarm)
            }
        val channels = mutableListOf(general)
        if (resources.getIdentifier("voice_fare_received", "raw", packageName) != 0) {
            channels += voice("konduct_voice_fare", "Payments received (spoken)", "Says \"Payment received\" the moment a fare is paid", "voice_fare_received")
        }
        if (resources.getIdentifier("voice_wallet_funded", "raw", packageName) != 0) {
            channels += voice("konduct_voice_wallet", "Wallet top-ups (spoken)", "Says when money lands in your wallet", "voice_wallet_funded")
        }
        channels += voice("konduct_voice_payout", "Payouts (spoken)", "Says when a payout is sent to your bank", "voice_payout_sent")
        manager.createNotificationChannels(channels)
        manager.deleteNotificationChannel("konduct_payments")
    }
}
