package co.broadcastapp.muckabout;

import android.util.Log;

public class RemoteStreamer {

    public String echo(String value) {
        Log.i("Echo", value);
        return value;
    }
}
