using UnityEngine;
using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine.Networking;

#if UNITY_IOS
using System.Runtime.InteropServices;
#endif

// This class manages all the native download functionality so the rest of the app doesn't 
// need to worry about which platform it is on
public class DownloadManager
{
    public const string ERROR_UNKNOWN_ID = "???";

    public static event Action<DownloadRequest, DownloadRequest.DownloadState> StateChanged = (arg1, arg2) => { };
    public static event Action<DownloadRequest, float> ProgressChanged = (arg1, atg2) => { };
    public static event Action<DownloadRequest, string> DownloadIdChanged = (arg1, arg2) => { };

#if UNITY_ANDROID && !UNITY_EDITOR
    private AndroidJavaClass _downloadService;
#elif UNITY_IOS && !UNITY_EDITOR
    [DllImport ("__Internal")]
    private static extern string _startDownload(string url);

    [DllImport ("__Internal")]
    private static extern int _checkStatus(string id);

    [DllImport ("__Internal")]
    private static extern string _getError(string id);

    [DllImport ("__Internal")]
    private static extern bool _moveFile(string id, string destination);

    [DllImport ("__Internal")]
    private static extern void _removeFile(string id);
#else
    private Dictionary<string, UnityWebRequest> downloadDict = new Dictionary<string, UnityWebRequest>();
#endif

    private bool _isInit = false;

    public DownloadManager() { }

    public void Init()
    {
        if (_isInit)
        {
            return;
        }
        _isInit = true;

#if UNITY_ANDROID && !UNITY_EDITOR
        if (_downloadService == null)
        {
            _downloadService = new AndroidJavaClass("com.seismicgames.androiddownloader.DownloadService");
        }
#endif
    }

    public string StartDownload(string url, string filename, string cookie)
    {
        Init();

        string trackingGuid;
#if UNITY_ANDROID && !UNITY_EDITOR
		using (AndroidJavaObject downloadService = _downloadService.CallStatic<AndroidJavaObject>("getInstance"))
		{
			trackingGuid = downloadService.Call<string>("startDownload", url, filename, cookie);
		}
#elif UNITY_IOS && !UNITY_EDITOR
		trackingGuid = _startDownload(url);
#else

        Debug.LogFormat("[DownloadManager:StartDownload] starting for {0}", url);

        UnityWebRequest download = new UnityWebRequest(url);
        download.downloadHandler = new DownloadHandlerFileWriter(filename);
        download.Send();
        
		trackingGuid = Guid.NewGuid().ToString();
		downloadDict.Add(trackingGuid, download);
#endif

        Debug.LogFormat("[DownloadManager:StartDownload] UUID: {0} url {1} filename: {2}",
            trackingGuid, url, filename);

        return trackingGuid;
	}

	public int CheckDownload(string id)
	{
	    if (string.IsNullOrEmpty(id)) return -1;
		int position = 0;
#if UNITY_ANDROID && !UNITY_EDITOR		
		using (AndroidJavaObject downloadService = _downloadService.CallStatic<AndroidJavaObject>("getInstance"))
		{
			position = downloadService.Call<int>("checkStatus", id.ToString());
		}
#elif UNITY_IOS && !UNITY_EDITOR
		position = _checkStatus(id.ToString().ToUpper());
#else
	    UnityWebRequest request;
        if (downloadDict.TryGetValue(id, out request) && !ResponseCodeIsError(request.responseCode))
		{
			position = (int) Math.Floor(request.downloadProgress * 100);
		    if (!request.isDone) position = Math.Min(position, 99);
		} else {
			position = -1;
		}
#endif
        if (position == -1) {
#if UNITY_EDITOR
            if (request == null)
            {
                // request might not have started yet
                Debug.LogWarning("There is no request to check");
            }
            else
            {
                // there was an error
                Debug.LogErrorFormat("There was an error with the download: {0}", request.responseCode);
            }
#endif
			return position;
		} else {
			return position;
		}
	}

    public string GetError(string id)
    {
        if (string.IsNullOrEmpty(id)) return ERROR_UNKNOWN_ID;

#if UNITY_ANDROID && !UNITY_EDITOR
        using (AndroidJavaObject downloadService = _downloadService.CallStatic<AndroidJavaObject>("getInstance"))
        {
            return downloadService.Call<int>("getError", id).ToString();
        }
#elif UNITY_IOS && !UNITY_EDITOR
        return _getError(id);
#else
        UnityWebRequest request;
        if (downloadDict.TryGetValue(id, out request))
        {
            return request.isNetworkError ? request.error : request.responseCode.ToString();
        }
        return ERROR_UNKNOWN_ID;
#endif
    }

    public void RemoveDownload(string id)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        using (AndroidJavaObject downloadService = _downloadService.CallStatic<AndroidJavaObject>("getInstance"))
        {
            downloadService.Call("removeDownload", id);
        }
#elif UNITY_IOS && !UNITY_EDITOR
        _removeFile(id);
#else
        if (!downloadDict[id].isDone)
        {
            downloadDict[id].Abort();
        }
        var handler = downloadDict[id].downloadHandler as DownloadHandlerFileWriter;
        if (handler != null) handler.DeleteFile();
        downloadDict[id].Dispose();
        downloadDict.Remove(id);
#endif
    }

    public bool MoveFile(string id, string dest)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        using (AndroidJavaObject downloadService = _downloadService.CallStatic<AndroidJavaObject>("getInstance"))
        {
            return downloadService.Call<bool>("moveFile", id, dest);
        }
#elif UNITY_IOS && !UNITY_EDITOR
        return _moveFile(id, dest);
#else
        var handler = downloadDict[id].downloadHandler as DownloadHandlerFileWriter;
        var moved = false;

        if (handler != null) { moved = handler.MoveFile(dest);}

        RemoveDownload(id);

        return moved;
#endif
    }

    public bool VerifyFile(string dest, string md5Hash)
    {
        var md5 = new System.Security.Cryptography.MD5CryptoServiceProvider();
        using (Stream fileStream = new FileStream(dest, FileMode.Open))
        {
            md5.ComputeHash(fileStream);
        }
        var fileHash = md5.Hash;

        for (int i = 0; i + 1 < md5Hash.Length; i += 2)
        {
            if (!fileHash[i/2].Equals(Convert.ToByte(md5Hash.Substring(i, 2), 16)))
            {
                return false;
            }
            
        }
        return true;
    }

    public void TrackDownloadIds(params string[] ids)
    {
#if !UNITY_EDITOR &&  UNITY_ANDROID
        long[] nativeIds = new long[ids.Length];
        for (int index = 0; index < ids.Length; index++)
        {
            nativeIds[index] = long.Parse(ids[index]);
        }

        using(AndroidJavaClass notifServiceClass = new AndroidJavaClass("com.seismicgames.androiddownloader.DownloadNotificationService"))
        {
            notifServiceClass.CallStatic("startTrackingIds", nativeIds);
        }
#endif
    }

    private bool ResponseCodeIsError(long responseCode)
    {
        return !(responseCode == -1 || (responseCode >= 200 && responseCode < 300));
    }

    public static bool ErrorIsRecoverableWithRetry(string errorCode)
    {
        if (errorCode.Equals(ERROR_UNKNOWN_ID)) return true;

        int intErrorCode;
        if (int.TryParse(errorCode, out intErrorCode))
        {
            if (intErrorCode >= 500 && intErrorCode < 600) return true;
        }
        return false;
    }

    public void OnStateChanged(DownloadRequest req, DownloadRequest.DownloadState state)
    {
        StateChanged(req, state);
    }

    public void OnProgressChanged(DownloadRequest req, float progress)
    {
        ProgressChanged(req, progress);
    }

    public void OnDownloadIdChanged(DownloadRequest req, string downloadId)
    {
        DownloadIdChanged(req, downloadId);
    }

    public DownloadRequest BuildRequest(string url, string destPath, string md5Hash = null)
    {
        return new DownloadRequest(url, destPath, md5Hash, this);
    }
}

#if UNITY_EDITOR
public class DownloadHandlerFileWriter : DownloadHandlerScript, IDisposable
{
    private readonly string _cachePath;
    private readonly Stream _outStream;
    private long _contentLength = -1;
    private long _bytesRead = 0;

    public DownloadHandlerFileWriter(string fileName)
    {
        _cachePath = Path.Combine(Application.temporaryCachePath, fileName);
        _outStream = new FileStream(_cachePath, FileMode.OpenOrCreate);
    }

    protected override void ReceiveContentLength(int contentLength)
    {
        _contentLength = contentLength;
        base.ReceiveContentLength(contentLength);
    }

    protected override bool ReceiveData(byte[] data, int dataLength)
    {
        _outStream.Write(data, 0, dataLength);
        _bytesRead += dataLength;
        return base.ReceiveData(data, dataLength);
    }

    protected override float GetProgress()
    {
        if (_contentLength > 0) return (float) _bytesRead/_contentLength;
        return base.GetProgress();
    }

    void IDisposable.Dispose()
    {
        Dispose();
    }

    protected override void CompleteContent()
    {
        _outStream.Dispose();
        base.CompleteContent();
    }

    public new void Dispose()
    {
        _outStream.Dispose();
        base.Dispose();
    }

    public void DeleteFile()
    {
        _outStream.Dispose();
        try
        {
            File.Delete(_cachePath);
        }
        catch (Exception e)
        {
            Debug.LogException(e);
        }
    }

    public bool MoveFile(string dest)
    {
        _outStream.Dispose();
        try
        {
            if(File.Exists(dest)) File.Delete(dest);

            File.Move(_cachePath, dest);
            return true;
        }
        catch (Exception e)
        {
            Debug.LogException(e);
        }
        return false;
    }
}
#endif