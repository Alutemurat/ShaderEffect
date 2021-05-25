Shader "Unlit/LearnRainDrop"
{
    Properties
    {
        _Color ("Color",COLOR) = (1,1,1,1)
        _Albedo ("Texture", 2D) = "white" {}
        [NoScaleOffset]
        _NormalMap ("Normal", 2D) = "bump" {}
        [NoScaleOffset]
        _Metallic ("Metallic", 2D) = "white" {}
        _MetallicFactor("Metallic",Range(0,1))=0
        [NoScaleOffset]
        _Roughness ("Roughness", 2D) = "white" {}
        _RoughnessFactor("Roughness",Range(0,1))=0
        [NoScaleOffset]
        _AO ("Occlusion", 2D) = "white" {}

        _PointAmount("Point Amount",Float)=15
        _PointCut("Point Cut",Range(0,1))=1
        _PointPositiveNormal("Point Positive Normal",Range(0,1))=0.235
        _PointNegativeNormal("Point Negative Normal",Range(0,1))=0.140

        _RainDropAmount("Rain Drop Amount",Float)=5
        _RainDropCut("Rain Drop Cut",Range(0,1))=1
        _RainDropPositiveNormal("Rain Drop Positive Normal",Range(0,1))=0.235
        _RainDropNegativeNormal("Rain Drop Negative Normal",Range(0,1))=0.140

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityStandardUtils.cginc"

            #include "RainDrop.cginc"
            #include "MyPBS.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 TtoW0:TEXCOORD1;
				float4 TtoW1:TEXCOORD2;
				float4 TtoW2:TEXCOORD3;

                LIGHTING_COORDS(4,5)
            };

            sampler2D _Albedo;
            sampler2D _NormalMap,_Metallic,_Roughness,_AO;
            float4 _Albedo_ST;
            half _MetallicFactor,_RoughnessFactor;
            fixed4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Albedo);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float4 tangentWorld=float4(UnityObjectToWorldDir(v.tangent.xyz),v.tangent.w);
				float3 worldNormal=UnityObjectToWorldNormal(v.normal);
				float3x3 tangentToWorld=CreateTangentToWorldPerVertex(worldNormal,tangentWorld.xyz,tangentWorld.w);

                o.TtoW0=float4(tangentToWorld[0],worldPos.x);
				o.TtoW1=float4(tangentToWorld[1],worldPos.y);
				o.TtoW2=float4(tangentToWorld[2],worldPos.z);

                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                float t=_Time.y;

                float3x3 tanToWorld;
				tanToWorld[0]=i.TtoW0.xyz;
				tanToWorld[1]=i.TtoW1.xyz;
				tanToWorld[2]=i.TtoW2.xyz;

                float3 worldPos=float3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w);
                RainDropData rain=RainDrop(i.uv,worldPos,tanToWorld);

                fixed4 baseColor=tex2D(_Albedo, i.uv)*_Color;
                baseColor.rgb=(baseColor.rgb+rain.rainColor)*rain.fullMask;

                float roughness=tex2D(_Roughness,i.uv).r*_RoughnessFactor;
                float metallic=tex2D(_Metallic,i.uv).r*_MetallicFactor;
                float ao=tex2D(_AO,i.uv).r;

                float3 normal =UnpackNormal(tex2D(_NormalMap,i.uv));
                normal=BlendNormals(normal,rain.normal);
                //normal=rain.normal;
                normal = TransfromTanToWorld(normal,tanToWorld);

                roughness=max(0,roughness-rain.rainTrace);
                //roughness=1-rain.rainTrace;
                float3 RMA=float3(roughness,metallic,ao);
                fixed4 lightAndAtten=fixed4(_LightColor0.rgb,LIGHT_ATTENUATION(i));

                fixed4 col=myBRDF(worldPos,normal,baseColor.rgb,RMA,lightAndAtten);
                //col.rgb=rain.fullMask;
                return col;
            }
            ENDCG
        }
    }

    Fallback "Diffuse"
}
