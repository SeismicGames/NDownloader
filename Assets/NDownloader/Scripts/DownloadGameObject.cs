using UnityEngine;
using System;

public class DownloadGameObject : MonoBehaviour
{
	private static ILogger logger = Debug.logger;
	public static DownloadGameObject Instance = null;

	void Awake()
	{
		if (Instance != null)
		{
			Destroy(gameObject); // There can be only one
			return;
		}
		Instance = this;
		DontDestroyOnLoad(gameObject);
		this.name = "DownloadGameObject";
	}

	void OnApplicationPause(bool pauseStatus)
	{
		if(pauseStatus)
		{
			// on pause
		}
		else
		{
			// on resume
		}
	}

	void OnDestroy()
	{
		if (Instance != this)
		{
			return;
		}

		Instance = null;
	}

	public void LogVerbose(string message)
	{
		logger.Log(LogType.Log, message);
	}

	public void LogDebug(string message)
	{
		logger.Log(LogType.Log, message);
	}

	public void LogInfo(string message)
	{
		logger.Log(LogType.Log, message);
	}

	public void LogWarn(string message)
	{
		logger.Log(LogType.Warning, message);
	}

	public void LogError(string message)
	{
		logger.Log(LogType.Error, message);
	}
}
