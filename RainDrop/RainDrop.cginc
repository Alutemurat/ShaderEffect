#ifndef RAIN_DROP
#define RAIN_DROP

float _PointAmount,_PointCut,_PointPositiveNormal,_PointNegativeNormal;
float _RainDropAmount,_RainDropCut,_RainDropPositiveNormal,_RainDropNegativeNormal;
float _UseNormal;

struct RainDropData
{
    float3 normal;
    fixed3 rainColor;
    fixed fullMask;
    fixed rainTrace;
};

float3 N13(float2 uv)
{
    float p=uv.x*35.2+uv.y*2376.1;
    float3 p3 = frac(float3(p,p,p) * float3(.1031,.11369,.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return frac(float3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float3 BlendNormals(float3 n1,float3 n2)
{
    n1.z=n1.z+1;
    n2.xy=-n2.xy;
    float NdotN=dot(n1,n2);
    
    return n1*NdotN-n2*n1.z;
}

// XY:frac  ZW:floor
float4 UVConfigure(float2 uv,float time,float2 scale,float amount)
{
    uv=uv*scale;
    uv.y+=time;
    //根据U值给随机值将UV错开
    float factor=frac(sin(floor(amount*uv.x)*12345.580078)*7658.759766);
    uv.y+=factor;
    uv*=amount;

    float4 Out=0;
    //floor:返回小于等于x的最大整数。
    //进行分区
    Out.zw=floor(uv);

    //frac返回输入值的小数部分。
    //x[0,1]---->[-0.5,0.5]
    //将uv分块
    Out.xy=frac(uv)-float2(0.5,0);
    //Out.xy=frac(uv);
    return Out;
}

float4 RainDropAndPointUV(float3 N,float2 fracUV,float time,float4 tillingOffset,float Cut,out float cut)
{
    cut=Cut;
    cut=floor(cut+N.y);

    half2 offsetUV=0;
    offsetUV.x=(N.x-0.5)*0.5;

    float v=frac(N.y+time);
    v=smoothstep(0,0.85,v)*smoothstep(1,0.85,v)-0.5;
    offsetUV.y=v*0.5+0.5;

    float2 uv=(fracUV-offsetUV)*tillingOffset.xy;
    //float2 uv=fracUV*2;
    return float4(offsetUV,uv);
}


float2 Mask(float2 uv,float3 scaleAndDir,float4 smoothRange,float2 cutAndBase)
{
    //取负突出暗部，再和噪声相加获取渐变效果
    float maskBase=length(uv*scaleAndDir.xy)*scaleAndDir.z+cutAndBase.y;
    float2 mask=1;
    //内圈 凹
    mask.x=smoothstep(smoothRange.x,smoothRange.y,maskBase)*cutAndBase.x;
    //外圈 凸
    mask.y=smoothstep(smoothRange.z,smoothRange.w,maskBase)*cutAndBase.x;
    return mask;
}


void TUV(float2 uv,float2 PosiNegaNormal,out float3 normal,out float3 causticNormal)
{
    normal=0;
    causticNormal=0;

    normal.y=abs(uv.x)*abs(uv.x)+uv.y;
    normal.x=abs(uv.y)*abs(uv.y)+uv.x;
    causticNormal.xy=-normal.xy;

    normal.z=PosiNegaNormal.x;
    normal=normalize(normal);

    causticNormal.z=PosiNegaNormal.y;
    causticNormal=normalize(causticNormal);
}

float3 TransfromTanToWorld(float3 normal,float3x3 tanToworld)
{
    float3 worldNormal;
    worldNormal.x = dot(tanToworld[0], normal);
    worldNormal.y = dot(tanToworld[1], normal);
    worldNormal.z = dot(tanToworld[2], normal);
    return normalize(worldNormal);
}

float RainTrace(float2 uv,float2 fracUV)
{
    float lineWidth=abs(fracUV.x-uv.x);
    float lineHeight=smoothstep(1,uv.y,fracUV.y);

    float base=sqrt(lineHeight);
    float widthMax=base*0.23;
    float widthMin=base*0.15*base;
    lineWidth=smoothstep(widthMax,widthMin,lineWidth);

    float trace=smoothstep(-0.02,0.02,fracUV.y-uv.y)*lineHeight;
    trace*=lineWidth;
    return max(0,trace);
}

RainDropData MixStaticDynamic(float3 normal,float3 causticNormal,float2 mask,
									float3 dropNormal,float3 dropCausticNormal,float2 dropMask,
									float3 viewDir,float3x3 tanToWorld)
{
    RainDropData rain=(RainDropData)0;

    float3 lightDir=float3(-0.3,1,-0.3);
    lightDir=normalize(lightDir);
    float3 halfDir=normalize(viewDir+lightDir);
    float3 yDir=float3(0,1,0);

    fixed downMask=mask.x+dropMask.x;
    fixed riseMask=mask.y+dropMask.y;

    float3 riseNormal=lerp(normal,dropNormal,dropMask.y);
    //float3 useNormal=BlendNormals(riseNormal,float3(0,0,1));
    riseNormal=TransfromTanToWorld(riseNormal,tanToWorld);
    float RdotV=smoothstep(0.9,1.2,dot(riseNormal,halfDir));
    RdotV*=RdotV;

    float3 downNormal=lerp(causticNormal,dropCausticNormal,dropMask.x);
    float3 useNormal=BlendNormals(downNormal,float3(0,0,1));
    downNormal=TransfromTanToWorld(downNormal,tanToWorld);
    float DdotC=smoothstep(0.5,1.5,dot(downNormal,lightDir));
    DdotC*=DdotC;

    float RdotZ=smoothstep(-1.3,0.3,dot(yDir,riseNormal));
    fixed fullMask=saturate(lerp(1,RdotZ,riseMask)+downMask);
    //fixed fullMask=lerp(1,RdotZ,riseMask);

    fixed3 rainDiffuseColor=RdotV*downMask*10;
    fixed3 rainCausticColor=DdotC*downMask*4;

    rain.normal=useNormal;
    rain.rainColor=rainDiffuseColor+rainCausticColor;
    rain.fullMask=fullMask;
    
    return rain;
}

// RainDropData MixStaticDynamicLight(float3 normal,float3 causticNormal,float2 mask,
// 									float3 dropNormal,float3 dropCausticNormal,float2 dropMask,
// 									float3 worldPos,float3x3 tanToWorld)
// {
//     RainDropData rain=(RainDropData)0;

//     float3 viewDir=normalize(UnityWorldSpaceViewDir(worldPos));
//     float3 lightDir=normalize(float3(-0.3,1,-0.3));
//     //float3 lightDir=normalize(UnityWorldSpaceLightDir(worldPos));
//     float3 halfDir=normalize(viewDir+lightDir);
//     float3 yDir=float3(0,1,0);

//     fixed downMask=mask.x+dropMask.x;
//     fixed riseMask=mask.y+dropMask.y;

//     float3 riseNormal=lerp(normal,dropNormal,dropMask.y);
//     //float3 useNormal=BlendNormals(riseNormal,float3(0,0,1));
//     riseNormal=TransfromTanToWorld(riseNormal,tanToWorld);
//     float RdotV=smoothstep(0.9,1.2,dot(riseNormal,halfDir));
//     RdotV*=RdotV;

//     float3 downNormal=lerp(causticNormal,dropCausticNormal,dropMask.x);
//     float3 useNormal=BlendNormals(downNormal,float3(0,0,1));
//     useNormal.z=_UseNormal;
//     downNormal=TransfromTanToWorld(downNormal,tanToWorld);
//     float DdotC=smoothstep(0.5,1.5,dot(downNormal,lightDir));
//     DdotC*=DdotC;

//     float RdotZ=smoothstep(-1.3,0.3,dot(yDir,riseNormal));
//     fixed fullMask=saturate(lerp(1,RdotZ,riseMask)+downMask);
//     //fixed fullMask=lerp(1,RdotZ,riseMask);

//     fixed3 rainDiffuseColor=RdotV*downMask*10;
//     fixed3 rainCausticColor=DdotC*downMask*4;

//     rain.normal=useNormal;
//     rain.rainColor=rainDiffuseColor+rainCausticColor;
//     rain.fullMask=fullMask;
    
//     return rain;
// }

RainDropData RainDrop(float2 uv,float3 worldPos,float3x3 tanToWorld)
{
    RainDropData rainData=(RainDropData)0;
    float t=_Time.y;
    float cut;

//静态水滴-------------------
    float4 configure=UVConfigure(uv,0,1,_PointAmount);
    float3 N=N13(configure.zw);
    float4 rain=RainDropAndPointUV(N,configure.xy,0,float4(2,2,0,0),_PointCut,cut);

    //噪声值慢慢变大,由frac再变回0
    float fade=smoothstep(0.2,1,1-frac(t*0.05+N.z));
    float2 mask=Mask(rain.zw,float3(3.54,2.1,-1),float4(0.3,0.44,0.1,0.45),float2(cut,fade));
    //float2 mask=Mask(rain.zw,float3(3.54,2.1,-1),float4(0.1,0.44,0.1,0.45),float2(cut,fade));

    //法线
    float3 normal,causticNormal;
    float2 factor=float2(_PointPositiveNormal,_PointNegativeNormal); 
    TUV(rain.zw,factor,normal,causticNormal);
    float3 up=float3(0,0,1);
    normal=lerp(up,normal,mask.y);
    causticNormal=lerp(up,causticNormal,mask.x);
//--------------------------

    float4 configureDrop=UVConfigure(uv,0.02*t,float2(5,1), _RainDropAmount);
    N=N13(configureDrop.zw);
    float4 rainDrop=RainDropAndPointUV(N,configureDrop.xy,t*0.05,float4(1,5,0,0),_RainDropCut,cut);
    float2 rainDropMask=Mask(rainDrop.zw,float3(2.9,1.8,1),float4(0.68,0.44,0.8,0.57),float2(cut,0));
    //float2 rainDropMask=Mask(rainDrop.zw,float3(2.9,1.8,1),float4(0.75,0.57,0.8,0.57),float2(cut,0));
    float rainDropTrace=RainTrace(rainDrop.xy,configureDrop.xy)*cut+mask.x+rainDropMask.x;

    float3 dropNormal,dropCausticNormal;
    factor=float2(_RainDropPositiveNormal,_RainDropNegativeNormal);
    TUV(rainDrop.zw,factor,dropNormal,dropCausticNormal);
    dropNormal*=rainDropMask.y;
    dropCausticNormal*=rainDropMask.x;

    float3 viewDir=normalize(UnityWorldSpaceViewDir(worldPos));
    rainData=MixStaticDynamic(normal,causticNormal,mask,dropNormal,dropCausticNormal,rainDropMask,viewDir,tanToWorld);
    // rainData=MixStaticDynamicLight(normal,causticNormal,mask,dropNormal,
    //                 dropCausticNormal,rainDropMask,worldPos,tanToWorld);
    rainData.rainTrace=rainDropTrace;

    return rainData;
}

#endif