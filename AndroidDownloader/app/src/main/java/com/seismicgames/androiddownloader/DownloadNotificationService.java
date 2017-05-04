package com.seismicgames.androiddownloader;

import android.app.DownloadManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.database.Cursor;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.support.v4.app.NotificationCompat;
import android.util.Log;

import com.unity3d.player.UnityPlayer;

import java.util.HashSet;
import java.util.Set;

/**
 * Created by admin on 12/21/2016.
 */

public class DownloadNotificationService extends Service {

    private static final String ACTION_SET_DOWNLOAD_IDS = DownloadManager.class.getName() + ".ACTION_SET_DOWNLOAD_IDS";
    public static final String ACTION_CHECK_DOWNLOADS = DownloadManager.class.getName() + ".ACTION_CHECK_DOWNLOADS";
    private static final String ACTION_CANCEL_DOWNLOADS = DownloadManager.class.getName() + ".ACTION_CANCEL_DOWNLOADS";
    private static final String EXTRAS_DOWNLOAD_IDS = DownloadManager.class.getName() + ".EXTRAS_DOWNLOAD_IDS";

    private static final String PREFERENCE_DOWNLOAD_IDS = DownloadManager.class.getName() + ".PREFERENCE_DOWNLOAD_IDS";

    private static final int NOTIFICATION_ID = 1;


    @SuppressWarnings("unused")
    public static void startTrackingIds(long[] ids){
        Context context = UnityPlayer.currentActivity;
        Intent intent = new Intent(context, DownloadNotificationService.class);
        intent.setAction(ACTION_SET_DOWNLOAD_IDS);
        intent.putExtra(EXTRAS_DOWNLOAD_IDS, ids);
        context.startService(intent);
    }

    private HandlerThread mWorkThread;
    private Handler mHandler;
    private UpdateNotificationRunnable progressUpdateRunnable;

    @Override
    public void onCreate() {
        super.onCreate();
        mWorkThread = new HandlerThread("DownloadNotificationService");
        mWorkThread.start();
        mHandler = new Handler(mWorkThread.getLooper());


        long[] ids = getStoredIds();
        if(ids.length > 0) {
            scheduleProgressUpdates(ids);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i("LocalService", "Received start id " + startId + ": " + intent);


        if(intent != null) {
            if (ACTION_SET_DOWNLOAD_IDS.equals(intent.getAction())) {
                long[] ids = intent.getLongArrayExtra(EXTRAS_DOWNLOAD_IDS);
                storeIds(ids);
                scheduleProgressUpdates(ids);
            }else if(ACTION_CANCEL_DOWNLOADS.equals(intent.getAction())) {
                long[] ids = intent.getLongArrayExtra(EXTRAS_DOWNLOAD_IDS);
                mHandler.post(new CancelRunnable(ids));
            }else if (ACTION_CHECK_DOWNLOADS.equals(intent.getAction())){
                long[] ids = getStoredIds();
                if(ids.length <= 0) {
                    stopSelf(startId);
                    return START_NOT_STICKY;
                }
            }else{
                stopSelf(startId);
                return START_NOT_STICKY;
            }
        }

        return START_STICKY;
    }


    @Override
    public void onDestroy() {
        super.onDestroy();
        if(progressUpdateRunnable != null) progressUpdateRunnable.cancel();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            mWorkThread.quitSafely();
        }else {
            mWorkThread.quit();
        }
    }


    private void storeIds(long [] ids){
        SharedPreferences prefs = getSharedPreferences("downloadIds", MODE_PRIVATE);

        Set<String> idSet = new HashSet<>();
        for (long id : ids) {
            idSet.add(String.valueOf(id));
        }

        prefs.edit().putStringSet(PREFERENCE_DOWNLOAD_IDS, idSet).apply();
    }

    private long[] getStoredIds(){
        SharedPreferences prefs = getSharedPreferences("downloadIds", MODE_PRIVATE);
        Set<String> idSet = prefs.getStringSet(PREFERENCE_DOWNLOAD_IDS, new HashSet<String>());
        long[] ids = new long[idSet.size()];

        int index = 0;
        for (String id : idSet) {
           ids[index] = Integer.parseInt(id);
            index++;
        }
        return ids;
    }


    public String getApplicationName() {
        ApplicationInfo applicationInfo = getApplicationInfo();
        int stringId = applicationInfo.labelRes;
        return stringId == 0 ? getString(R.string.app_name) : getString(stringId);
    }


    private void scheduleProgressUpdates(long[] ids) {
        if (progressUpdateRunnable != null) {
            progressUpdateRunnable.cancel();
        }
        progressUpdateRunnable = new UpdateNotificationRunnable(ids);
        mHandler.post(progressUpdateRunnable);
    }


    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private PendingIntent buildOpenAppIntent() {
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);
    }

    private PendingIntent buildCancelIntent(long[] ids) {
        Intent intent = new Intent(this, DownloadNotificationService.class);
        intent.setAction(ACTION_CANCEL_DOWNLOADS);
        intent.putExtra(EXTRAS_DOWNLOAD_IDS, ids);
        return PendingIntent.getService(this, 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);
    }


    private class UpdateNotificationRunnable implements Runnable{

        private final long[] ids;
        private volatile boolean canceled = false;
        private NotificationCompat.Builder notificationBuilder;
        private UpdateNotificationRunnable(long[] ids) {
            this.ids = ids;

            notificationBuilder = new NotificationCompat.Builder(getApplicationContext());
            notificationBuilder .setSmallIcon(android.R.drawable.stat_sys_download)  // the status icon
                    .setContentIntent(buildOpenAppIntent())
                    //.setTicker(text)  // the status text
                    .setWhen(System.currentTimeMillis())  // the time stamp
                    .setContentTitle(getApplicationName())  // the label of the entry
                    //.setContentText(text)  // the contents of the entry
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, getString(android.R.string.cancel), buildCancelIntent(ids))
                    .setProgress(100, 0, false);
                    //.setContentIntent(contentIntent)  // The intent to send when the entry is clicked

        }

        public void cancel(){
            canceled = true;
            mHandler.removeCallbacks(this);
        }

        @Override
        public void run() {
            DownloadManager downloadManager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);

            DownloadManager.Query query = new DownloadManager.Query();
            query.setFilterById(ids);


            NotificationManager notificationManager = ((NotificationManager) getSystemService(NOTIFICATION_SERVICE));
            boolean downloadsIncomplete = false;
            boolean allDownloadsSuccessful = true;

            Cursor c = null;
            try {
                c = downloadManager.query(query);

                long totalBytesSoFar = 0;
                long totalBytes = 0;
                while (c.moveToNext()) {
                    totalBytesSoFar += c.getLong(c.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                    totalBytes += c.getLong(c.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));

                    int status = c.getInt(c.getColumnIndex(DownloadManager.COLUMN_STATUS));
                    downloadsIncomplete |= status == DownloadManager.STATUS_PAUSED || status == DownloadManager.STATUS_PENDING || status == DownloadManager.STATUS_RUNNING;
                    allDownloadsSuccessful &= status == DownloadManager.STATUS_SUCCESSFUL;
                }
                //do not mark 0 downloads as a success.
                allDownloadsSuccessful &= c.getPosition() > 0;


                if (totalBytes > 0) {
                    int progress = (int) ((totalBytesSoFar * 100) / totalBytes);
                    notificationBuilder.setProgress(100, progress, progress == 100);
                    notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build());
                }
            } finally {
                if (c != null) c.close();
            }

            if(!canceled) {
                if (downloadsIncomplete) {
                    mHandler.postDelayed(this, 1000);
                } else {
                    Log.d("DOWNLOADS", "downloads complete");
                    if( allDownloadsSuccessful) {
                        notificationBuilder.mActions.clear();
                        notificationBuilder.setSmallIcon(android.R.drawable.stat_sys_download_done);
                        notificationBuilder.setProgress(100, 100, false);
                        notificationBuilder.setAutoCancel(true);
                        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build());
                    } else {
                        notificationManager.cancel(NOTIFICATION_ID);
                    }
                    //clear stored ids;
                    storeIds(new long[0]);
                    stopSelf();
                }
            }
        }

    }

    private class CancelRunnable implements Runnable{
        private final long[] ids;

        private CancelRunnable(long[] ids) {
            this.ids = ids;
        }

        @Override
        public void run() {
            if(progressUpdateRunnable != null){
                progressUpdateRunnable.cancel();
            }

            DownloadManager downloadManager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
            downloadManager.remove(ids);

            NotificationManager notificationManager = ((NotificationManager)getSystemService(NOTIFICATION_SERVICE));
            notificationManager.cancel(NOTIFICATION_ID);
        }
    }

}





