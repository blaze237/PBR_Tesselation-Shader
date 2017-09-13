using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
public class RealWaterShaderEditor : CustomMaterialEditor
{
    protected override void CreateToggleList()
    {
        Toggles.Add(new FeatureToggle("Refraction", "Refraction", "REFRACTION_ON", "REFRACTION_OFF"));
        Toggles.Add(new FeatureToggle("Tesselation", "tessellation", "TESS_ON", "TESS_OFF"));

    }
}
/*
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Linq;

public class RealWaterShader : MaterialEditor
{
    public override void OnInspectorGUI()
    {
        // Draw the default inspector.
        base.OnInspectorGUI();

        // If we are not visible, return.
        if (!isVisible)
            return;

        // Get the current keywords from the material
        Material targetMat = target as Material;
        string[] keyWords = targetMat.shaderKeywords;

        // Check to see if the keyword NORMALMAP_ON is set in the material.
        bool refractionEnabled = keyWords.Contains("REFRACTION_ON");
        EditorGUI.BeginChangeCheck();
        // Draw a checkbox showing the status of refractionEnabled
        refractionEnabled = EditorGUILayout.Toggle("Refraction Enabled", refractionEnabled);
        // If something has changed, update the material.
        if (EditorGUI.EndChangeCheck())
        {
            // If our normal is enabled, add keyword NORMALMAP_ON, otherwise add NORMALMAP_OFF
            List<string> keywords = new List<string> { refractionEnabled ? "REFRACTION_ON" : "REFRACTION_OFF" };
            targetMat.shaderKeywords = keywords.ToArray();
            EditorUtility.SetDirty(targetMat);
        }
    }
}

*/