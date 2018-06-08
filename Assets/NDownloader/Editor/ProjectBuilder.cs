using UnityEditor;
using UnityEngine;
using System;
using System.IO;
using System.Collections.Generic;
using UnityEditor.Build.Reporting;

public class ProjectBuilder : EditorWindow {
    private static string BasePath;

    public enum Platform
    {
        None,
        iOS,
        Android
    }

    private class BuildValues
    {
        public BuildTargetGroup btg;
        public BuildTarget bt;

        public BuildValues(Platform platform)
        {
            switch (platform)
            {
                case Platform.iOS:
                    btg = BuildTargetGroup.iOS;
                    bt = BuildTarget.iOS;
                    break;
                case Platform.Android:
                    btg = BuildTargetGroup.Android;
                    bt =  BuildTarget.Android;
                    break;
            }
        }
    }

    private Platform platform = Platform.None;
    string outputLocation = BasePath + Path.DirectorySeparatorChar + "build";
    bool debugBuild;

    [MenuItem("Build/Build Player")]
    public static void BuildMenu()
    {
        EditorWindow window = EditorWindow.GetWindow(typeof(ProjectBuilder), false, "Build Player", true);
        window.maxSize = new Vector2(500f, 250f);
        window.minSize = window.maxSize;
    }
    
    [MenuItem("Build/Clear Build Prefs")]
    public static void ClearPrefs()
    {
        if(EditorUtility.DisplayDialog("Clear Build Prefs", "Do you want to clear build preferences?", "Yes", "No")) {
            EditorPrefs.DeleteKey("ProjectBuilder.platform");
            EditorPrefs.DeleteKey("ProjectBuilder.outputLocation");
            EditorPrefs.DeleteKey("ProjectBuilder.debugBuild");

            EditorWindow window = EditorWindow.GetWindow(typeof(ProjectBuilder), false, "Build Player", true);
            window.Close();

            UnityEngine.Debug.ClearDeveloperConsole();
            UnityEngine.Debug.Log("Build perferences cleared!");
        }
    }

    void OnGUI()
    {
        GUILayout.Label("Build Settings", EditorStyles.boldLabel);
        EditorGUILayout.Space();
        GUIContent label = new GUIContent();
        label.text = "Platform";
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.PrefixLabel(label);
        platform = (Platform)EditorGUILayout.EnumPopup(platform, GUILayout.Width(150));
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.BeginHorizontal();
        outputLocation = EditorGUILayout.TextField("Output Location", outputLocation);
        GUI.SetNextControlName("Browse");
        if (GUILayout.Button("Browse"))
        {
            outputLocation = EditorUtility.SaveFolderPanel("Select Location", outputLocation, "Builds");
            GUI.FocusControl("Browse");
        }
        EditorGUILayout.EndHorizontal();

        debugBuild = EditorGUILayout.Toggle("Debug Build", debugBuild);

        if (GUILayout.Button("Build", GUILayout.Width(200)))
        {
            if(platform != Platform.None && !string.IsNullOrEmpty(outputLocation))
            {
                BuildGame(platform);
            }
        }

    }

    public void OnEnable()
    {
        BasePath = Directory.GetParent(Application.dataPath).ToString();
        
        if (platform == Platform.None && EditorPrefs.HasKey("ProjectBuilder.platform"))
        {
            platform = (Platform)Enum.Parse(typeof(Platform), EditorPrefs.GetString("ProjectBuilder.platform"), true);
        }

        if (outputLocation == null && EditorPrefs.HasKey("ProjectBuilder.outputLocation"))
        {
            outputLocation = EditorPrefs.GetString("ProjectBuilder.outputLocation");
        }

        if (EditorPrefs.HasKey("ProjectBuilder.debugBuild"))
        {
            debugBuild = EditorPrefs.GetBool("ProjectBuilder.debugBuild");
        }
    }

    public void OnDisable()
    {
        if (platform != Platform.None)
        {
            EditorPrefs.SetString("ProjectBuilder.platform", platform.ToString());
        }

        if (outputLocation != null)
        {
            EditorPrefs.SetString("ProjectBuilder.outputLocation", outputLocation);
        }

        EditorPrefs.SetBool("ProjectBuilder.debugBuild", debugBuild);
    }

    public void BuildGame(Platform platform)
    {
        UnityEngine.Debug.ClearDeveloperConsole();
        UnityEngine.Debug.Log(string.Format("Starting build for {0} ...", platform));
        
        List<string> scenes = new List<string>();
        for(int i = 0; i < EditorBuildSettings.scenes.Length; i++) {
            if(EditorBuildSettings.scenes[i].enabled) {
                scenes.Add(EditorBuildSettings.scenes[i].path);
            }
        }

        // build
        BuildPlayer(scenes.ToArray(), platform);
        
        AssetDatabase.SaveAssets();
        UnityEngine.Debug.Log("Finished!");
    }

    private void BuildPlayer(string[] scenes, Platform platform)
    {
        BuildOptions buildOptions = BuildOptions.None;

        if (debugBuild)
        {
            buildOptions |= BuildOptions.Development;
            buildOptions |= BuildOptions.AllowDebugging;
        }

        //TODO: add toggle
        PlayerSettings.Android.useAPKExpansionFiles = false;
        string updatedOutputLocation = outputLocation + Path.DirectorySeparatorChar + platform;

        if (Directory.Exists(updatedOutputLocation))
        {
            Directory.Delete(updatedOutputLocation, true);
        }
        Directory.CreateDirectory(updatedOutputLocation);

        switch (platform)
        {
            case Platform.Android:
                updatedOutputLocation = updatedOutputLocation + Path.DirectorySeparatorChar + Application.productName + ".apk";
                break;
            case Platform.iOS:
                updatedOutputLocation = updatedOutputLocation + Path.DirectorySeparatorChar;
                break;
        }

        var bv = new BuildValues(platform);
        Debug.Log("Building project in directory: " + outputLocation + " with scenes: " + string.Join(",", scenes) + " options: " + buildOptions);
        Debug.Log(string.Format("Define symbols set to {0}", PlayerSettings.GetScriptingDefineSymbolsForGroup(bv.btg)));

        var report = BuildPipeline.BuildPlayer(scenes, updatedOutputLocation, bv.bt, buildOptions);

        if (report.summary.totalErrors > 0)
        {
            foreach (var step in report.steps)
            {
                foreach (var message in step.messages)
                {
                    if (message.type == LogType.Error)
                    {
                        Debug.LogError("Build Error: " + message);
                    }                
                }
            }
        }

        if (UnityEditorInternal.InternalEditorUtility.isHumanControllingUs)
        {
            if (report.summary.totalErrors > 0)
            {
                EditorUtility.DisplayDialog("Build Failed", "Build Failed", "Close");
            }
            else
            {
                EditorUtility.DisplayDialog("Build Complete", "Build has been completed successfully.", "Close");
            }
        }
    }

    [MenuItem("Build/Clear Downloads")]
    public static void ClearDownloads()
    {
        string path = Application.persistentDataPath + Path.DirectorySeparatorChar;
        Debug.Log(string.Format("[ProjectBuilder:ClearDownloads] Clearing out {0}", path));
        foreach (string file in Directory.GetFiles(path, "*.zip"))
        {
            File.Delete(file);
        }
    }
}
