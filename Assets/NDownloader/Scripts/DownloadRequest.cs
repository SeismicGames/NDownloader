using System;
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;

public class DownloadRequest
{
    public enum DownloadState
    {
        Init,
        Downloading,
        Moving,
        Complete,
        Failed
    }

    //default so we dont have to null check
    public event Action<DownloadRequest, DownloadState> StateChanged = (arg1, arg2) => { };
    public event Action<DownloadRequest, float> ProgressChanged = (arg1, arg2) => { };
    public event Action<DownloadRequest, string> DownloadIdChanged = (arg1, arg2) => { };

    private readonly string _url;
    private readonly string _destPath;
    private readonly string _md5Hash;

    public string Url { get { return _url; } }
    public string DestinationPath { get { return _destPath; } }

    private DownloadState _state;
    public DownloadState State
    {
        get { return _state; }
        private set
        {
            _state = value;
            StateChanged(this, value);
            _manager.OnStateChanged(this, value);
        }
    }

    private float _progress = 0f;
    public float Progress
    {
        get { return _progress; }
        private set
        {
            _progress = value;
            ProgressChanged(this, value);
            _manager.OnProgressChanged(this, value);
        }
    }

    private DownloadManager _manager;

    private string _downloadId;
    public string DownloadId
    {
        get { return _downloadId; }
        private set
        {
            if (_downloadId != value)
            {
                _downloadId = value;
                DownloadIdChanged(this, value);
                _manager.OnDownloadIdChanged(this, value);
            }
        }
    }

    public string Cookie { get; set; }

    public string ErrorCode { get; private set; }

    public DownloadRequest(string url, string destPath, string md5Hash = null) : this(url, destPath, md5Hash, null)
    {
    }

    public DownloadRequest(string url, string destPath, string md5Hash = null, DownloadManager manager = null)
    {
        _url = url;
        _destPath = destPath;
        _md5Hash = md5Hash;
        _manager = manager ?? new DownloadManager();
    }

    public IEnumerator VerifyOrDownloadFile()
    {
        _manager.Init();

        //reset
        _downloadId = null;

        //if file exists in path -> done
        if (File.Exists(_destPath))
        {
            State = DownloadState.Downloading;
            bool verified;
            if (_md5Hash != null)
            {
                var verifyRoutine = WorkOffMainRoutine(_manager.VerifyFile, _destPath, _md5Hash, false);
                while (verifyRoutine.MoveNext()) { yield return null; }
                verified = verifyRoutine.Current;
            }
            else
            {
                verified = true;
            }
            if (verified)
            {
                State = DownloadState.Complete;
                yield break;
            }
        }

        DownloadId = GetDownloadId(_url, _destPath);

        while (true)
        {
            var checkStatusRoutine = WorkOffMainRoutine(_manager.CheckDownload, DownloadId, -1);
            while (checkStatusRoutine.MoveNext()) { yield return null; }
            var checkStatus = checkStatusRoutine.Current;

            if (checkStatus == 100)
            {
                Progress = 100f;

                // move file
                var moveRoutine = WorkOffMainRoutine(_manager.MoveFile, DownloadId, _destPath, false);
                while (moveRoutine.MoveNext()) { yield return null; }
                var wasMoved = moveRoutine.Current;
                if (wasMoved)
                {
                    State = DownloadState.Complete;
                    break;
                }

                //clear downloadId
                StoreDownloadId(_url, _destPath, null);
                var removeRoutine = WorkOffMainRoutine(_manager.RemoveDownload, DownloadId);
                while (removeRoutine.MoveNext()) { yield return null; }
            }
            else if (checkStatus == -1)
            {
                Progress = 0f;

                var checkErrorRoutine = WorkOffMainRoutine(_manager.GetError, DownloadId, DownloadManager.ERROR_UNKNOWN_ID);
                while (checkErrorRoutine.MoveNext()) { yield return null; }
                var errorCode = checkErrorRoutine.Current;

                if (DownloadManager.ErrorIsRecoverableWithRetry(errorCode))
                {
                    //start download
                    State = DownloadState.Downloading;
                    string tempName = string.Format("{0}.tmp", string.IsNullOrEmpty(_md5Hash) ? Guid.NewGuid().ToString() : _md5Hash);

                    var startRoutine = WorkOffMainRoutine(_manager.StartDownload, _url, tempName, Cookie, null);
                    while (startRoutine.MoveNext()) { yield return null; }
                    DownloadId = startRoutine.Current;
                    StoreDownloadId(_url, _destPath, DownloadId);
                }
                else
                {
                    ErrorCode = errorCode;
                    StoreDownloadId(_url, _destPath, null);
                    State = DownloadState.Failed;
                    break;
                }
            }
            else
            {
                //update progress bar
                State = DownloadState.Downloading;
                Progress = checkStatus;
            }
            yield return new WaitForSeconds(0.1f);
        }
    }

    private IEnumerator<TResult> WorkOffMainRoutine<T1, T2, T3, TResult>(Func<T1, T2, T3, TResult> baseFunc, T1 param1,
        T2 param2, T3 param3, TResult defaultValue)
    {
#if UNITY_ANDROID && !UNITY_EDITOR
        TResult result = defaultValue;
        bool resultSet = false;

        Func<T1, T2, T3, TResult> func = (arg1, arg2, arg3) =>
        {
            AndroidJNI.AttachCurrentThread();
            var res = baseFunc(arg1, arg2, arg3);
            AndroidJNI.DetachCurrentThread();
            return res;
        };

        //begin async invoke
        func.BeginInvoke(param1, param2, param3,
            res =>
            {
                try
                {
                    result = func.EndInvoke(res);
                }
                catch (Exception e)
                {
                    Debug.LogException(e);
                    result = defaultValue;
                }
                finally
                {
                    resultSet = true;
                }
            },
            _manager);
        //wait for value
        while (!resultSet)
        {
            yield return defaultValue;
        }
        yield return result;
#else
        yield return baseFunc(param1, param2, param3);
#endif

    }

    private IEnumerator<TResult> WorkOffMainRoutine<T1, T2, TResult>(Func<T1, T2, TResult> func, T1 param1, T2 param2, TResult defaultValue)
    {
        return WorkOffMainRoutine((T1 t1, T2 t2, object ignored) => func(t1, t2), param1, param2, null, defaultValue);
    }

    private IEnumerator<TResult> WorkOffMainRoutine<T1, TResult>(Func<T1, TResult> func, T1 param, TResult defaultValue)
    {
        return WorkOffMainRoutine((T1 t1, object ignored) => func(t1), param, null, defaultValue);
    }

    private IEnumerator WorkOffMainRoutine<TParam>(Action<TParam> func, TParam param)
    {
        return WorkOffMainRoutine<TParam, object, object>((t1, ignored1) => { func(t1); return null; }, param, null, null);
    }

    private void StoreDownloadId(string url, string dest, string id)
    {
        PlayerPrefs.SetString(GetUrlKey(url, dest), id.ToString());
    }

    private string GetDownloadId(string url, string dest)
    {
        var id = PlayerPrefs.GetString(GetUrlKey(url, dest));
        return string.IsNullOrEmpty(id) ? null : id;
    }

    private string GetUrlKey(string url, string dest)
    {
        return string.Format("downloadID{0}{1}", url, dest);
    }
}