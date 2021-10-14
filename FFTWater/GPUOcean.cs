using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUOcean : MonoBehaviour
{
    public int FFTPow = 10;         //生成海洋纹理大小 2的次幂，例 为10时，纹理大小为1024*1024
    public float A = 0.5f;

    public Vector4 WindAndSeed = new Vector4(0.1f, 0.2f, 0, 0);
    //风向和随机种子 xy为风, zw为两个随机种子
    public float Lambda = -1;       //用来控制偏移大小
    public float HeightScale = 1;   //高度影响
    public float BubblesScale = 1;  //泡沫强度
    public float BubblesThreshold = 1;//泡沫阈值
    public float TimeScale = 1;
    public float WindScale = 2;     //风强
    public float OceanLength = 10f;

    public ComputeShader oceanShader;

    public RenderTexture GaussianRandomRT;             //高斯随机数
    public RenderTexture HeightSpectrumRT;             //高度频谱
    public RenderTexture DisplaceSpectrumRT;           //偏移频谱
    public RenderTexture DisplaceRT;                   //偏移频谱
    public RenderTexture OutputRT;
    public RenderTexture NormalRT;                     //法线纹理+泡沫纹理

    private int ComputeGaussianRandom;
    private int CreateHeightSpectrum;
    private int CreateDisplaceSpectrum;
    private int TextureGenerationDisplace;
    private int TextureGenerationNormalBubbles;
    private int FFTHorizontal;
    private int FFTVertical;

    private int size;
    private Material _matrial;
    private float time;

    void Start()
    {
        InitOceanData();
        _matrial = GetComponent<MeshRenderer>().sharedMaterial;
        _matrial.SetTexture("_Displace", DisplaceRT);
        _matrial.SetTexture("_Normal", NormalRT);
    }

    void Update()
    {
        ComputeOceanValue();
        time += Time.deltaTime * TimeScale;
    }

    private void OnDisable()
    {
        GaussianRandomRT.Release();
        HeightSpectrumRT.Release();
        DisplaceSpectrumRT.Release();
        DisplaceRT.Release();
        OutputRT.Release();
        NormalRT.Release();
    }

    private void InitOceanData()
    {
        size = (int)Mathf.Pow(2, FFTPow);

        GaussianRandomRT = CreateRT(size);
        HeightSpectrumRT = CreateRT(size);
        DisplaceSpectrumRT = CreateRT(size);
        DisplaceRT = CreateRT(size);
        OutputRT = CreateRT(size);
        NormalRT = CreateRT(size);

        ComputeGaussianRandom = oceanShader.FindKernel("ComputeGaussianRandom");
        CreateHeightSpectrum = oceanShader.FindKernel("CreateHeightSpectrum");
        CreateDisplaceSpectrum = oceanShader.FindKernel("CreateDisplaceSpectrum");
        TextureGenerationDisplace = oceanShader.FindKernel("TextureGenerationDisplace");
        TextureGenerationNormalBubbles = oceanShader.FindKernel("TextureGenerationNormalBubbles");
        FFTHorizontal = oceanShader.FindKernel("FFTHorizontal");
        FFTVertical = oceanShader.FindKernel("FFTVertical");

        WindAndSeed.z = Random.Range(1, 10f);
        WindAndSeed.w = Random.Range(1, 10f);
        oceanShader.SetInt("N", size);
        oceanShader.SetFloat("Lambda", Lambda);

        oceanShader.SetTexture(ComputeGaussianRandom,
            "GaussianRandomRT", GaussianRandomRT);
        oceanShader.Dispatch(ComputeGaussianRandom, size / 8, size / 8, 1);

    }

    private RenderTexture CreateRT(int size)
    {
        RenderTexture renderTexture = new RenderTexture(size, size, 0, 
            RenderTextureFormat.ARGBFloat);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();
        return renderTexture;
    }

    void ComputeFFT(int kernel,ref RenderTexture input)
    {
        oceanShader.SetTexture(kernel, "InputRT", input);
        oceanShader.SetTexture(kernel, "OutputRT", OutputRT);
        oceanShader.Dispatch(kernel, size / 8, size / 8, 1);

        //交换输入输出纹理
        RenderTexture rt = input;
        input = OutputRT;
        OutputRT = rt;
    }

    private void ComputeOceanValue()
    {
        oceanShader.SetFloat("A", A);
        oceanShader.SetVector("WindAndSeed", WindAndSeed.normalized*WindScale);
        oceanShader.SetFloat("Time", time);
        oceanShader.SetFloat("HeightScale", HeightScale);
        oceanShader.SetFloat("BubblesScale",BubblesScale);
        oceanShader.SetFloat("BubblesThreshold",BubblesThreshold);
        oceanShader.SetFloat("OceanLength",OceanLength);

        oceanShader.SetTexture(CreateHeightSpectrum, "GaussianRandomRT",
            GaussianRandomRT);
        oceanShader.SetTexture(CreateHeightSpectrum, "HeightSpectrumRT",
            HeightSpectrumRT);
        oceanShader.Dispatch(CreateHeightSpectrum, size / 8, size / 8, 1);

        oceanShader.SetTexture(CreateDisplaceSpectrum, "HeightSpectrumRT",
            HeightSpectrumRT);
        oceanShader.SetTexture(CreateDisplaceSpectrum, "DisplaceSpectrumRT",
            DisplaceSpectrumRT);
        oceanShader.Dispatch(CreateDisplaceSpectrum, size / 8, size / 8, 1);

        for (int i = 1; i <= FFTPow; i++)
        {
            int ns = (int)Mathf.Pow(2, i - 1);
            oceanShader.SetInt("Ns", ns);
            oceanShader.SetBool("IsEnd", i == FFTPow);
            ComputeFFT(FFTHorizontal, ref HeightSpectrumRT);
            ComputeFFT(FFTHorizontal, ref DisplaceSpectrumRT);
        }

        for (int i = 1; i <= FFTPow; i++)
        {
            int ns = (int)Mathf.Pow(2, i - 1);
            oceanShader.SetInt("Ns", ns);
            oceanShader.SetBool("IsEnd", i == FFTPow);
            ComputeFFT(FFTVertical, ref HeightSpectrumRT);
            ComputeFFT(FFTVertical, ref DisplaceSpectrumRT);
        }

        oceanShader.SetTexture(TextureGenerationDisplace, "HeightSpectrumRT",
            HeightSpectrumRT);
        oceanShader.SetTexture(TextureGenerationDisplace, "DisplaceSpectrumRT",
            DisplaceSpectrumRT);
        oceanShader.SetTexture(TextureGenerationDisplace, "DisplaceRT", DisplaceRT);
        oceanShader.Dispatch(TextureGenerationDisplace, size / 8, size / 8, 1);

        oceanShader.SetTexture(TextureGenerationNormalBubbles, "DisplaceRT", DisplaceRT);
        oceanShader.SetTexture(TextureGenerationNormalBubbles, "NormalRT", NormalRT);
        oceanShader.Dispatch(TextureGenerationNormalBubbles, size / 8, size / 8, 1);
    }
}
