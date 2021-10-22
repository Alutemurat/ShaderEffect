using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine;
using System;
using UnityEngine.Rendering;

[Serializable]
[PostProcess(typeof(ColorTintRenderer), PostProcessEvent.AfterStack, "Unity/ColorTint")]
public class ColorTint : PostProcessEffectSettings
{
    public TextureParameter noise3D = new TextureParameter { value = null };
    public TextureParameter noiseDetail3D = new TextureParameter { value = null };
    public TextureParameter weather=new TextureParameter { value = null };
    public TextureParameter maskNoise = new TextureParameter { value = null };
    public TextureParameter blueNoise = new TextureParameter { value = null };

    public FloatParameter shapeTiling = new FloatParameter { value = 0.01f };
    public FloatParameter detailTiling = new FloatParameter { value = 0.1f };

    public ColorParameter colA = new ColorParameter { value = Color.white };
    public ColorParameter colB = new ColorParameter { value = Color.white };
    public FloatParameter colorOffset1 = new FloatParameter { value = 0.59f };
    public FloatParameter colorOffset2 = new FloatParameter { value = 1.02f };
    public FloatParameter lightAbsorptionTowardSun = new FloatParameter { value = 0.1f };
    public FloatParameter lightAbsorptionThroughCloud = new FloatParameter { value = 1 };
    public Vector4Parameter phaseParams = new Vector4Parameter { value = new Vector4(0.72f, 1, 0.5f, 1.58f) };

    public FloatParameter rayStep = new FloatParameter { value = 1.2f };
    public FloatParameter step=new FloatParameter { value = 1.2f };
    public FloatParameter rayOffsetStrength = new FloatParameter { value = 1.5f };

    public FloatParameter densityOffset = new FloatParameter { value = 4.02f };
    public FloatParameter densityMultiplier = new FloatParameter { value = 2.31f };
    public Vector4Parameter speedAndWarp = new Vector4Parameter { value = new Vector4(0.05f, 1, 1, 10) };
    [Range(0, 1)]
    public FloatParameter heightWeights = new FloatParameter { value = 1 };
    public Vector4Parameter shapeNoiseWeights = new Vector4Parameter { value = new Vector4(-0.17f, 27.17f, -3.65f, -0.08f) };
    public FloatParameter detailWeights = new FloatParameter { value = -3.76f };
    public FloatParameter detailNoiseWeight = new FloatParameter { value = 0.12f };
}

public sealed class ColorTintRenderer : PostProcessEffectRenderer<ColorTint>
{
    GameObject findCloudBox;
    Transform cloudTransform;
    Vector3 boundsMin;
    Vector3 boundsMax;

    public override void Init()
    {
        Debug.Log("Init");
        findCloudBox = GameObject.Find("CloudBox");
        if (findCloudBox != null)
        {
            Debug.Log("CloudBox");
            cloudTransform = findCloudBox.GetComponent<Transform>();
        }
    }

    public override void Render(PostProcessRenderContext context)
    {
        CommandBuffer cmd = context.command;
        cmd.BeginSample("ScreenColorTint");

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/PostProcessing/ColorTint"));

        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
        sheet.properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
        sheet.properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"), context.camera.cameraToWorldMatrix);

        if (cloudTransform != null)
        {
            boundsMin = cloudTransform.position - cloudTransform.localScale / 2;
            boundsMax = cloudTransform.position + cloudTransform.localScale / 2;

            sheet.properties.SetVector(Shader.PropertyToID("_BoundsMin"), boundsMin);
            sheet.properties.SetVector(Shader.PropertyToID("_BoundsMax"), boundsMax);
        }

        if (settings.noise3D.value != null)
        {
            sheet.properties.SetTexture("_NoiseTex", settings.noise3D.value);
        }

        if (settings.noiseDetail3D.value != null)
        {
            sheet.properties.SetTexture(Shader.PropertyToID("_NoiseDetail3D"), settings.noiseDetail3D.value);
        }

        if (settings.weather.value != null)
        {
            sheet.properties.SetTexture("_WeatherMap", settings.weather.value);
        }

        if (settings.maskNoise.value != null)
        {
            sheet.properties.SetTexture(Shader.PropertyToID("_MaskNoise"), settings.maskNoise.value);
        }

        if (settings.blueNoise.value != null)
        {
            Vector4 screenUV = new Vector4(
            (float)context.screenWidth / (float)settings.blueNoise.value.width,
            (float)context.screenHeight / (float)settings.blueNoise.value.height, 0, 0);
            sheet.properties.SetVector(Shader.PropertyToID("_BlueNoiseCoords"), screenUV);
            sheet.properties.SetTexture(Shader.PropertyToID("_BlueNoise"), settings.blueNoise.value);
        }


        sheet.properties.SetFloat(Shader.PropertyToID("_RayStep"), settings.rayStep.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_Step"), settings.step.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_RayOffsetStrength"), settings.rayOffsetStrength.value);
        sheet.properties.SetVector(Shader.PropertyToID("_PhaseParams"), settings.phaseParams.value);

        sheet.properties.SetColor(Shader.PropertyToID("_ColA"), settings.colA.value);
        sheet.properties.SetColor(Shader.PropertyToID("_ColB"), settings.colB.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_ColorOffset1"), settings.colorOffset1.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_ColorOffset2"), settings.colorOffset2.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_LightAbsorptionTowardSun"), settings.lightAbsorptionTowardSun.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_LightAbsorptionThroughCloud"), settings.lightAbsorptionThroughCloud.value);

        sheet.properties.SetFloat(Shader.PropertyToID("_DensityOffset"), settings.densityOffset.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_DensityMultiplier"), settings.densityMultiplier.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_ShapeTiling"), settings.shapeTiling.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_DetailTiling"), settings.detailTiling.value);
        sheet.properties.SetVector(Shader.PropertyToID("_SpeedAndWarp"), settings.speedAndWarp.value);
        sheet.properties.SetVector(Shader.PropertyToID("_ShapeNoiseWeights"), settings.shapeNoiseWeights.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_HeightWeights"), settings.heightWeights.value);

        sheet.properties.SetFloat(Shader.PropertyToID("_DetailWeights"), settings.detailWeights.value);
        sheet.properties.SetFloat(Shader.PropertyToID("_DetailNoiseWeight"), settings.detailNoiseWeight.value);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

        cmd.EndSample("ScreenColorTint");
    }
}
