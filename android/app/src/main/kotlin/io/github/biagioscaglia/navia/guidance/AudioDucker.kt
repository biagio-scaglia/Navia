package io.github.biagioscaglia.navia.guidance

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build

/**
 * Lowers other audio, such as music or a podcast, while an instruction is
 * spoken, and gives it back afterwards: transient audio focus that lets
 * other players duck instead of pausing.
 */
class AudioDucker(context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var request: AudioFocusRequest? = null
    private var held = false

    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    /** Returns whether other audio was asked to duck. */
    fun duck(): Boolean {
        if (held) return true
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val focus = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener { }
                .build()
            request = focus
            audio.requestAudioFocus(focus)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
        }
        held = granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return held
    }

    fun release() {
        if (!held) return
        held = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            request?.let { audio.abandonAudioFocusRequest(it) }
            request = null
        } else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(null)
        }
    }
}
