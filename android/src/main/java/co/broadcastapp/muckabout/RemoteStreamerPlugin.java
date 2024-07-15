package co.broadcastapp.muckabout;

import android.content.Context;

import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.PlaybackException;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.ProgressiveMediaSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;


@CapacitorPlugin(name = "RemoteStreamer")
public class RemoteStreamerPlugin extends Plugin {
    private ExoPlayer player;
    private DefaultDataSourceFactory dataSourceFactory;

    @Override
    public void load() {
        super.load();
        Context context = getContext();
        dataSourceFactory = new DefaultDataSourceFactory(context, Util.getUserAgent(context, "RemoteStreamer"));
    }

    @PluginMethod
    public void play(PluginCall call) {
        String url = call.getString("url");
        if (url == null) {
            call.reject("URL is required");
            return;
        }

        releasePlayer();
        player = new ExoPlayer.Builder(getContext()).build();

        MediaSource mediaSource;
        if (url.endsWith(".m3u8")) {
            mediaSource = new HlsMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(url));
        } else {
            mediaSource = new ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(url));
        }

        player.setMediaSource(mediaSource);
        player.prepare();
        player.play();

        setupPlayerListeners();

        notifyListeners("play", new JSObject());
        call.resolve();
    }

    private void setupPlayerListeners() {
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                switch (state) {
                    case Player.STATE_BUFFERING:
                        notifyListeners("buffering", new JSObject().put("isBuffering", true));
                        break;
                    case Player.STATE_READY:
                        notifyListeners("buffering", new JSObject().put("isBuffering", false));
                        break;
                    case Player.STATE_ENDED:
                        notifyListeners("stop", new JSObject());
                        break;
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                notifyListeners("error", new JSObject().put("message", error.getMessage()));
            }

            @Override
            public void onPositionDiscontinuity(Player.PositionInfo oldPosition, Player.PositionInfo newPosition, int reason) {
                notifyListeners("timeUpdate", new JSObject().put("currentTime", player.getCurrentPosition()));
            }
        });
    }

    @PluginMethod
    public void pause(PluginCall call) {
        if (player != null) {
            player.pause();
            notifyListeners("pause", new JSObject());
        }
        call.resolve();
    }

    @PluginMethod
    public void resume(PluginCall call) {
        if (player != null) {
            player.play();
            notifyListeners("play", new JSObject());
        }
        call.resolve();
    }

    @PluginMethod
    public void seekTo(PluginCall call) {
        long position = call.getLong("position", 0L);
        if (player != null) {
            player.seekTo(position);
        }
        call.resolve();
    }

    @PluginMethod
    public void stop(PluginCall call) {
        releasePlayer();
        notifyListeners("stop", new JSObject());
        call.resolve();
    }

    private void releasePlayer() {
        if (player != null) {
            player.release();
            player = null;
        }
    }

    @Override
    protected void handleOnDestroy() {
        releasePlayer();
        super.handleOnDestroy();
    }
}
