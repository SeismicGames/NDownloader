package com.seismicgames.androiddownloader;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Created by admin on 12/22/2016.
 */

public class DownloadReceiverProxy extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Intent checkProgressIntent = new Intent(context, DownloadNotificationService.class);
        checkProgressIntent.setAction(DownloadNotificationService.ACTION_CHECK_DOWNLOADS);
        context.startService(checkProgressIntent);
    }
}
