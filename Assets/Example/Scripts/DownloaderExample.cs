using UnityEngine;
using UnityEngine.UI;
using ProgressBar;
using System;
using System.IO;

public class DownloaderExample : MonoBehaviour
{
	public Text ProgressText;
    public Text URLText;
	public ProgressRadialBehaviour ProgressBar;

    private DownloadManager _manager;
    public DownloadManager Manager
    {
        get { return _manager ?? (_manager = new DownloadManager()); }
    }

    // Use this for initialization
    void Start ()
    {
		ProgressBar.Value = 0.0f;

        // register callbacks
        DownloadManager.StateChanged += OnStateChanged;
        DownloadManager.ProgressChanged += OnProgressChanged;
        DownloadManager.DownloadIdChanged += OnDownloadIdChanged;

        string destFile = Application.persistentDataPath + Path.DirectorySeparatorChar + "20MB.zip";
        string url = "http://ipv4.download.thinkbroadband.com/20MB.zip";
        DownloadRequest request = new DownloadRequest(url, destFile, "9017804333c820e3b4249130fc989e00");
        StartCoroutine(request.VerifyOrDownloadFile());

        destFile = Application.persistentDataPath + "/100MB.zip";
        url = "http://ipv4.download.thinkbroadband.com/100MB.zip";
        request = new DownloadRequest(url, destFile, "5b563100babfef2f2ec9ab2d55e97fd1");
        StartCoroutine(request.VerifyOrDownloadFile());
    }

    private void OnProgressChanged(DownloadRequest req, float progress)
    {
        if (URLText.text == req.Url)
        {
            ProgressBar.Value = progress;
        }
    }

    private void OnStateChanged(DownloadRequest req, DownloadRequest.DownloadState state)
    {
        switch (state)
        {
            case DownloadRequest.DownloadState.Init:
                break;
            case DownloadRequest.DownloadState.Downloading:
            case DownloadRequest.DownloadState.Moving:
                ProgressText.text = "Downloading...";

                if (URLText.text == string.Empty)
                {
                    URLText.text = req.Url;
                    ProgressBar.Value = 0.0f;
                }

                break;
            case DownloadRequest.DownloadState.Complete:
                ProgressText.text = "Download Finished!";
                URLText.text = string.Empty;
                break;
            case DownloadRequest.DownloadState.Failed:
                ProgressText.text = "Download Failed!";
                URLText.text = string.Empty;
                break;
            default:
                throw new ArgumentOutOfRangeException("state", state, null);
        }
    }

    private void OnDownloadIdChanged(DownloadRequest req, string downloadId)
    {
        Manager.TrackDownloadIds(downloadId);
    }
}
