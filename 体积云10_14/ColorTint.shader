Shader "Hidden/PostProcessing/ColorTint"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

            sampler3D _NoiseTex;
            sampler3D _NoiseDetail3D;
            sampler2D _WeatherMap;
            sampler2D _MaskNoise;
            sampler2D _BlueNoise;

            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;
            float4 _BlueNoiseCoords;

            float4x4 _InverseProjectionMatrix,_InverseViewMatrix;
            float4 _BoundsMin,_BoundsMax;

            float4 _ColA;
            float4 _ColB;
            float4 _PhaseParams;
            float _HeightWeights;

            float _Step;
            float _RayStep;
            float _RayOffsetStrength;
            float _ColorOffset1;
            float _ColorOffset2;
            float _DarknessThreshold;
            float _DetailWeights;
            float _DetailNoiseWeight;

            float _LightAbsorptionTowardSun;
            float _LightAbsorptionThroughCloud;

            float _ShapeTiling;
            float _DetailTiling;
            float4 _SpeedAndWarp;
            float4 _ShapeNoiseWeights;
            float _DensityOffset;
            float _DensityMultiplier;

            float3 _WorldSpaceLightPos0;
            float4 _LightColor0;

            //计算世界空间坐标
            float4 GetWorldSpacePosition(float depth, float2 uv)
            {
                // 屏幕空间 --> 视锥空间
                float4 view=mul(_InverseProjectionMatrix,float4(2*uv-1,depth,1));
                view.xyz/=view.w;
                //视锥空间 --> 世界空间
                float4 wolrd=mul(_InverseViewMatrix,float4(view.xyz,1));
                return wolrd;
            }

            float Remap(float originalValue,float originalMin,float originalMax,float newMin,float newMax)
            {
                return newMin+(((originalValue-originalMin)/(originalMax-originalMin))*(newMax-newMin));
            }

                            //边界框最小值       边界框最大值         
            float2 RayBoxDst(float3 boundsMin, float3 boundsMax, 
                            //世界相机位置      反向视角方向
                            float3 rayOrigin, float3 invRaydir) 
            {
                float3 t0=(boundsMin-rayOrigin)*invRaydir;
                float3 t1=(boundsMax-rayOrigin)*invRaydir;
                float3 tmin=min(t0,t1);
                float3 tmax=max(t0,t1);

                float dstA=max(max(tmin.x,tmin.y),tmin.z);//进入点
                float dstB=min(tmax.x,min(tmax.y,tmax.z));//出去点

                float dstToBox=max(0,dstA);
                float dstInsideBox=max(0,dstB-dstToBox);
                return float2(dstToBox,dstInsideBox);
            }

            float SampleDensity(float3 rayPos)
            {   
                float4 boundsCentre=(_BoundsMax+_BoundsMin)*0.5;
                float3 size=(_BoundsMax-_BoundsMin).xyz;
                float speedShape=_Time.y*_SpeedAndWarp.x;
                float speedDetail=_Time.y*_SpeedAndWarp.y;

                float3 uvwShape=rayPos*_ShapeTiling+float3(speedShape,speedShape*0.2,0);
                float3 uvwDetail=rayPos*_DetailTiling+float3(speedDetail,speedDetail*0.2,0);

                float2 uv=(size.xz*0.5+(rayPos.xz-boundsCentre.xz))/max(size.x,size.z);

                float4 maskNoise=tex2Dlod(_MaskNoise,float4(uv+float2(speedShape*0.5,0),0,0));
                float4 weather=tex2Dlod(_WeatherMap,float4(uv+float2(speedShape*0.4,0),0,0));
                float4 shapeNoise=tex3Dlod(_NoiseTex,float4(uvwShape+(maskNoise.r*_SpeedAndWarp.z*0.1),0));
                float4 detailNoise=tex3Dlod(_NoiseDetail3D,float4(uvwDetail+(shapeNoise.r*_SpeedAndWarp.w*0.1),0));

                float heightPercent=(rayPos.y-_BoundsMin.y)/size.y;//计算一个梯度值
                float gMin=Remap(weather.x,0,1,0.1,0.6);
                float gMax=Remap(weather.x,0,1,gMin,0.9);
                float heightGradient=saturate(Remap(heightPercent,0,gMin,0,1))*saturate(Remap(heightPercent,1,gMax,0,1));
                float heightGradient2=saturate(Remap(heightPercent,0,weather.r,1,0)*Remap(heightPercent,0,gMin,0,1));
                heightGradient=saturate(lerp(heightGradient,heightGradient2,_HeightWeights));

                //边框边缘来一个衰减
                const float edgeFade=10;
                float dstX=min(edgeFade,min(rayPos.x-_BoundsMin.x,_BoundsMax.x-rayPos.x));
                float dstZ=min(edgeFade,min(rayPos.z-_BoundsMin.z,_BoundsMax.z-rayPos.z));
                float edgeWeight=min(dstX,dstZ)/edgeFade;
                heightGradient*=edgeWeight;

                float4 normalizedSW=_ShapeNoiseWeights/dot(_ShapeNoiseWeights,1);
                float shapeFBM=dot(shapeNoise,normalizedSW)*heightGradient;
                float baseShapeDensity=shapeFBM+_DensityOffset*0.01;

                if(baseShapeDensity>0)
                {
                    float detailFBM=pow(detailNoise.r,_DetailWeights);
                    float oneMinusShape=1-baseShapeDensity;
                    float detailEW=oneMinusShape*oneMinusShape*oneMinusShape;
                    float cloudDensity=baseShapeDensity-detailFBM*detailEW*_DetailNoiseWeight;

                    return saturate(cloudDensity*_DensityMultiplier);
                }

                return 0;
            }

            float3 LightMarch(float3 position,float dstTravelled)
            {
                float3 ditToLight=_WorldSpaceLightPos0.xyz;
                float dstInsideBox=RayBoxDst(_BoundsMin.xyz,_BoundsMax.xyz,position,1/ditToLight).y;
                float stepSize=dstInsideBox/8;
                float totalDensity=0;

                [unroll(8)]
                for (int step = 0; step < 8; step++) {//灯光步进次数
                    position+=ditToLight*stepSize;//向灯光步进
                    totalDensity+=max(0,SampleDensity(position));//步进的时候采样噪音累计受灯光影响密度
                }

                float transmittance=exp(-totalDensity*_LightAbsorptionTowardSun);

                //将重亮到暗映射为 3段颜色 ,亮->灯光颜色 中->ColorA 暗->ColorB
                float3 cloudColor=lerp(_ColA,_LightColor0,saturate(transmittance*_ColorOffset1)).rgb;
                cloudColor=lerp(_ColB.rgb,cloudColor,saturate(pow(transmittance*_ColorOffset2,3)));

                return transmittance*cloudColor;
                //return _DarknessThreshold+transmittance*(1-_DarknessThreshold)*cloudColor;
            }

            //HG phase function
            float Hg(float a,float g)
            {
                float g2=g*g;
                return (1-g2)/(4*3.1415*pow(abs(1+g2-2*g*a),1.5));
            }

            float Phase(float a)
            {
                float blend=0.5;
                float hgBlend=Hg(a,_PhaseParams.x)*(1-blend)+Hg(a,-_PhaseParams.y)*blend;
                return _PhaseParams.z+hgBlend*_PhaseParams.w;
            }

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float depth=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoordStereo);
                //世界空间坐标
                float4 worldPos = GetWorldSpacePosition(depth, i.texcoord);
                float3 rayPos = _WorldSpaceCameraPos;
                //相机到每个像素的世界方向
                float3 worldViewDir = normalize(worldPos.xyz - rayPos.xyz) ;
                float depthEyeLinear=length(worldPos.xyz-_WorldSpaceCameraPos);
                float2 rayToContainerInfo=RayBoxDst(_BoundsMin.xyz,_BoundsMax.xyz,rayPos,(1/worldViewDir));
                float dstToBox = rayToContainerInfo.x; //相机到容器的距离
                float dstInsideBox = rayToContainerInfo.y; //返回光线是否在容器中
                //相机到物体的距离 - 相机到容器的距离，这里跟 光线是否在容器中 取最小，过滤掉一些无效值
                float dstLimit = min(depthEyeLinear - dstToBox, dstInsideBox);

                //相机起始点 + (世界空间相机到物体方向 * 相机边界框距离 )
                float3 entryPoint=rayPos+worldViewDir*dstToBox;

                float cosAngle=dot(worldViewDir,_WorldSpaceLightPos0.xyz);
                float3 phaseVal=Phase(cosAngle);

                float blueNoise=tex2D(_BlueNoise,i.texcoord*_BlueNoiseCoords.xy+_BlueNoiseCoords.zw).r;

                float sumDensity = 1;
                float dstTravelled = blueNoise*_RayOffsetStrength;
                float stepSize=exp(_Step)*_RayStep;
                const int sizeLoop = 512;
                float3 lightEnergy = 0;

                //[unroll(32)]
                for (int j = 0; j <sizeLoop; j++)
                {
                    if ( dstTravelled<dstLimit) //被遮住时步进跳过
                    {
                        rayPos=entryPoint+(worldViewDir*dstTravelled);
                        float density=SampleDensity(rayPos);
                        if(density>0)
                        {
                            float3 lightTransmittance=LightMarch(rayPos,dstTravelled);
                            lightEnergy+=density*stepSize*sumDensity*lightTransmittance*phaseVal;
                            sumDensity*=exp(-density*stepSize*_LightAbsorptionThroughCloud);

                            if(sumDensity<0.01) 
                                break;
                        }
                    }
                    dstTravelled += stepSize; //每次步进长度
                }

                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

                //float cloud=CloudRayMarching(rayPos,worldViewDir);
                color.rgb*=sumDensity;
                color.rgb+=lightEnergy;
                //return float4(lightEnergy,sumDensity);

                return color;
            }
            ENDHLSL
        }
    }
}
