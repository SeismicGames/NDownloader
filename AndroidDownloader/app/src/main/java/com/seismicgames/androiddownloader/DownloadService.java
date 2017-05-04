package com.seismicgames.androiddownloader;

import android.app.DownloadManager;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.unity3d.player.UnityPlayer;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;


public class DownloadService {
    private static final String TAG = "DownloadService";
    private static final String GAMEOBJ_NAME = "DownloadGameObject";
    private static DownloadService ourInstance = new DownloadService();
    private DownloadManager downloadManager;
    private Map<Long, DownloadInfo> downloadReverseMap;

    private class DownloadInfo {
        public long id;
        public String fileName;

        public DownloadInfo(long id, String fileName) {
            this.id = id;
            this.fileName = fileName;
        }
    }

    public static DownloadService getInstance() {
        return ourInstance;
    }

    private DownloadService() {
        downloadReverseMap = new HashMap<>();
        downloadManager = (DownloadManager) UnityPlayer.currentActivity.getSystemService(Context.DOWNLOAD_SERVICE);

//        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
//        UnityPlayer.currentActivity.registerReceiver(downloadReceiver, filter);
    }

    /**
     * Starts the file download in DownloadManager
     *
     * @param url      - URL to download
     * @param fileName - filename to save from URL
     * @return - the string version of the UUID for tracking
     */
    public String startDownload(String url, String fileName, String cookie) {
        return startDownload(url, fileName, cookie, false);
    }

    /**
     * Starts the file download in DownloadManager
     *
     * @param url      - URL to download
     * @param fileName - filename to save from URL
     * @return - the string version of the UUID for tracking
     */
    public String startDownload(String url, String fileName, String cookie, boolean allowMobile) {
        Uri uri = Uri.parse(url);

        //force unique tmp file name
        fileName  += UUID.randomUUID().toString();

        int networkTypes = DownloadManager.Request.NETWORK_WIFI;
        if (allowMobile) networkTypes |= DownloadManager.Request.NETWORK_MOBILE;

        DownloadManager.Request request = new DownloadManager.Request(uri)
                .addRequestHeader("Accept-Encoding", "gzip, deflate")
                .setAllowedOverRoaming(false)
                .setAllowedNetworkTypes(networkTypes)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_HIDDEN)
                .setVisibleInDownloadsUi(false)
                .addRequestHeader("Cookie", cookie);
        if(cookie != null && cookie.length() > 0) {
            request.setDestinationInExternalFilesDir(
                    UnityPlayer.currentActivity.getApplicationContext(),
                    Environment.DIRECTORY_DOWNLOADS,
                    fileName);
        }

        long id = downloadManager.enqueue(request);
        downloadReverseMap.put(id, new DownloadInfo(id, fileName));
        return String.valueOf(id);
    }

    /**
     * Get download status
     *
     * @param downloadId - String version of UUID id
     * @return - a value 0 to 100 percent of download finished, or -1 if error or can't be found
     */
    public int checkStatus(String downloadId) {
        int result;
        long id;
        try {
            id = Long.parseLong(downloadId);
        } catch (IllegalArgumentException e) {
            DownloadService.unityLog(Log.ERROR, TAG, "%s is not a valid UUID", downloadId);
            return -1;
        }

        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterById(id);
        Cursor cursor = null;
        try {
            cursor = downloadManager.query(query);
            if (cursor.moveToFirst()) {
                if (!isDownloadOk(cursor)) {
                    return -1;
                }

                int current = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                int total = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));
                float progress = (float) current / (float) total;
                //clamp 0-99
                result = (int) Math.max(0, Math.min(99, progress * 100));
                if(cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)) == DownloadManager.STATUS_SUCCESSFUL){
                    result = 100;
                }
            } else {
                DownloadService.unityLog(Log.WARN, TAG, "ID %s was not found in DownloadManager, might have finished downloading",
                        downloadId);
                return -1;
            }
        } finally {
            if (cursor != null) cursor.close();
        }
        return result;
    }

    //returns either android error code as DownloadManager.ERROR_*, an http response code, or 2000 to signify app error
    public int getError(String downloadId) {
        long id;
        try {
            id = Long.parseLong(downloadId);
        } catch (IllegalArgumentException e) {
            DownloadService.unityLog(Log.ERROR, TAG, "%s is not a valid UUID", downloadId);
            return 2000;
        }

        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterById(id);
        Cursor cursor = null;
        try {
            cursor = downloadManager.query(query);
            if (cursor.moveToFirst()) {
                return cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_REASON));
            }
        } finally {
            if (cursor != null)  cursor.close();
        }
        return 2000;
    }

    public boolean moveFile(String downloadId, String dest) {
        long id;
        try {
            id = Long.parseLong(downloadId);
        } catch (IllegalArgumentException e) {
            DownloadService.unityLog(Log.WARN, TAG, "%s is not a valid UUID", downloadId);
            return false;
        }
        try {
            ParcelFileDescriptor pfd = downloadManager.openDownloadedFile(id);

            InputStream is = new ParcelFileDescriptor.AutoCloseInputStream(pfd);
            OutputStream os = new FileOutputStream(dest);
            copyLarge(is, os);

            is.close();
            os.close();

            removeDownload(downloadId);

            return true;
        } catch (IOException e) {
            Log.e(TAG, "could not move downloadId: "+ downloadId);
            e.printStackTrace();
            return false;
        }

    }

    public void removeDownload(String downloadId) {
        long id;
        try {
            id = Long.parseLong(downloadId);
        } catch (IllegalArgumentException e) {
            DownloadService.unityLog(Log.WARN, TAG, "%s is not a valid UUID", downloadId);
            return;
        }

        DownloadManager.Query query = new DownloadManager.Query();
        query.setFilterById(id);
        Cursor cursor = null;
        try {
            cursor = downloadManager.query(query);

            if (cursor.moveToFirst()) {

                String uriString = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI));
                if (uriString.startsWith("file")) {
                    File f = new File(URI.create(uriString));
                    if (f.exists() && !f.delete()) {
                        unityLog(Log.WARN, TAG, "could not delete file " + f);
                    }
                }
            }
        }finally {
            if(cursor != null) cursor.close();
        }

        if(downloadManager.remove(id) <= 0){
            unityLog(Log.WARN, TAG, "could not delete download " + id);
        }

    }

    private static long copyLarge(InputStream input, OutputStream output)
            throws IOException {
        byte[] buffer = new byte[1024 * 4];
        long count = 0;
        int n = 0;
        while (-1 != (n = input.read(buffer))) {
            output.write(buffer, 0, n);
            count += n;
        }
        return count;
    }

    /**
     * Check status of downloaded file
     *
     * @param cursor - DowmloadManager cursor
     * @return - if file failed downloading or not
     */
    private static boolean isDownloadOk(Cursor cursor) {
        boolean ok = true;
        String filename = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_TITLE));
        int reason = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_REASON));
        String message = "Download file id %s is %s -- %s";
        int result = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS));
        long id = cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_ID));

        switch (result) {
            case DownloadManager.STATUS_PENDING:
                DownloadService.unityLog(Log.DEBUG, TAG, message, id, "pending", filename);
                break;
            case DownloadManager.STATUS_RUNNING:
                DownloadService.unityLog(Log.DEBUG, TAG, message, id, "running", filename);
                break;
            case DownloadManager.STATUS_PAUSED:
                DownloadService.unityLog(Log.DEBUG, TAG, message, id, "paused", reason);
                break;
            case DownloadManager.STATUS_SUCCESSFUL:
                DownloadService.unityLog(Log.DEBUG, TAG, message, id, "successful", filename);
                break;
            case DownloadManager.STATUS_FAILED:
                DownloadService.unityLog(Log.ERROR, TAG, message, id, "failed", reason);
                ok = false;
                break;
            default:
                DownloadService.unityLog(Log.ERROR, TAG, "Unknown result: %s", result);
                break;
        }

        return ok;
    }

    /**
     * Logger for both native and Unity
     *
     * @param level   - Log level
     * @param tag     - String to use for the Android logger
     * @param message - Log message
     */
    public static void unityLog(int level, String tag, String message) {
        String unityMessage = String.format("%s: %s", tag, message);
        switch (level) {
            case Log.VERBOSE:
                Log.v(tag, message);
                UnityPlayer.UnitySendMessage(GAMEOBJ_NAME, "LogVerbose", unityMessage);
                break;
            case Log.DEBUG:
                Log.d(tag, message);
                UnityPlayer.UnitySendMessage(GAMEOBJ_NAME, "LogDebug", unityMessage);
                break;
            case Log.INFO:
                Log.i(tag, message);
                UnityPlayer.UnitySendMessage(GAMEOBJ_NAME, "LogInfo", unityMessage);
                break;
            case Log.WARN:
                Log.w(tag, message);
                UnityPlayer.UnitySendMessage(GAMEOBJ_NAME, "LogWarn", unityMessage);
                break;
            case Log.ERROR:
                Log.e(tag, message);
                UnityPlayer.UnitySendMessage(GAMEOBJ_NAME, "LogError", unityMessage);
                break;
        }
    }

    public static void unityLog(int level, String tag, String message, Object... objects) {
        DownloadService.unityLog(level, tag, String.format(message, objects));
    }
}
