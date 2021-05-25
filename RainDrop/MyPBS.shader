Shader "MyShader/TestPBS"
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

        // [Space(20)]
        // [Toggle(_DIRECT)] _EnableDirect("Direct PI", Float) = 0.0
        // [Toggle(_INDIRECT)] _EnableIndirect("Indirect PI", Float) = 0.0
        
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
            #pragma multi_compile_fwdadd_fullshadows  
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
                float3 tangentDir : TEXCOORD3;
                float3 bitangentDir : TEXCOORD4;
                LIGHTING_COORDS(5,6)
            };
            
            sampler2D _Albedo;
            sampler2D _NormalMap,_Metallic,_Roughness,_AO;
            float4 _Albedo_ST;
            half _MetallicFactor,_RoughnessFactor;
            fixed4 _Color;
            
            v2f vert(appdata_tan v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _Albedo);

                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            float D_DistributionGGX(float3 N,float3 H,float Roughness)
            {
                float a             = Roughness*Roughness;
                float a2            = a*a;
                float NH            = saturate(dot(N,H));
                float NH2           = NH*NH;
                float nominator     = a2;
                float denominator   = (NH2*(a2-1.0)+1.0);
                denominator         = UNITY_PI * denominator*denominator;
                
                return              nominator/ max(denominator,0.001) ;//防止分母为0
            }

            float3 F_FrenelSchlick(float HV,float3 F0)
            {
                return F0 +(1 - F0)*pow(1-HV,5);
            }

            float GeometrySchlickGGX(float NV,float Roughness)
            {
                float r = Roughness +1.0;
                float k = r*r / 8.0;      //直接光
                float nominator = NV;
                float denominator = k + (1.0-k) * NV;
                return nominator/ max(denominator,0.001) ;//防止分母为0
            }

            float G_GeometrySmith(float3 N,float3 V,float3 L,float Roughness)
            {
                float NV = saturate(dot(N,V));
                float NL = saturate(dot(N,L));

                float ggx1 = GeometrySchlickGGX(NV,Roughness);
                float ggx2 = GeometrySchlickGGX(NL,Roughness);

                return ggx1*ggx2;
            }

            float3 FresnelSchlickRoughness(float NV,float3 F0,float Roughness)
            {
                return F0 + (max(float3(1.0 - Roughness, 1.0 - Roughness, 1.0 - Roughness), F0) - F0) * pow(1.0 - NV, 5.0);
            }
            
            //拟合BRDFLUT贴图效果更好，更加节省性能
            //UE4 在 黑色行动2 上的修改版本
            float2 EnvBRDFApprox_UE4(float Roughness, float NoV )
            {
                // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
                // Adaptation to fit our G term.
                const float4 c0 = { -1, -0.0275, -0.572, 0.022 };
                const float4 c1 = { 1, 0.0425, 1.04, -0.04 };
                float4 r = Roughness * c0 + c1;
                float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
                float2 AB = float2( -1.04, 1.04 ) * a004 + r.zw;
                return AB;
            }

            // ToneMapping(色调映射)
            float3 ACESToneMapping(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x*(a*x+b))/(x*(c*x+d)+e));
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                i.normalDir = normalize(i.normalDir);
                float3x3 tangentTransform = float3x3( i.tangentDir, i.bitangentDir, i.normalDir);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 halfDir = normalize(viewDir+lightDir);
                
                float3 normal =UnpackNormal(tex2D(_NormalMap,i.uv));
                normal = normalize(mul(normal.xyz, tangentTransform));

                float HdotV=saturate(dot(halfDir,viewDir));
                float NdotV=saturate(dot(normal,viewDir));
                float NdotL=saturate(dot(normal,lightDir));
                float3 viewRef = reflect( -viewDir, normal);

                fixed4 baseColor=tex2D(_Albedo, i.uv)*_Color;
                float roughness=tex2D(_Roughness,i.uv).r*_RoughnessFactor;
                float metallic=tex2D(_Metallic,i.uv).r*_MetallicFactor;
                float ao=tex2D(_AO,i.uv).r;
                float3 F0=lerp(0.04,baseColor.rgb,metallic);
                float3 Radiance = _LightColor0.xyz;
                float attenuation = LIGHT_ATTENUATION(i);
                fixed4 FinalColor=1;
                
                //================== Direct Light  ============================================== //
                //Specular
                //Cook-Torrance BRDF
                float D = D_DistributionGGX(normal,halfDir,roughness);
                float3 F = F_FrenelSchlick(HdotV,F0);
                float G = G_GeometrySmith(normal,viewDir,lightDir,roughness);

                float3 KS = F;
                float3 KD = 1-KS;
                KD*=1-metallic;
                float3 nominator = D*F*G;
                float denominator = max(4*NdotV*NdotL,0.001);
                float3 Specular = nominator/denominator;
                
                //Diffuse
                float3 Diffuse = KD * baseColor.rgb;
                float3 DirectLight = (Diffuse + Specular)*NdotL *Radiance;

                //================== Indirect Light  ============================================== //
                //Specular
                float3 IndirectLight = 0;
                float3 irradianceSH = ShadeSH9(float4(normal,1));

                float mip=roughness*(1.7-0.7*roughness)* UNITY_SPECCUBE_LOD_STEPS;
                float4 rgb_mip = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,viewRef,mip);
                float3 EnvSpecularPrefilted = DecodeHDR(rgb_mip, unity_SpecCube0_HDR);

                float3 F_IndirectLight = FresnelSchlickRoughness(NdotV,F0,roughness);
                float2 env_brdf = EnvBRDFApprox_UE4(roughness,NdotV);
                float3 Specular_Indirect =EnvSpecularPrefilted*(F_IndirectLight * env_brdf.r + env_brdf.g);

                //Diffuse
                float3 KD_IndirectLight = 1 - F_IndirectLight;
                KD_IndirectLight *= 1 - metallic;
                float3 Diffuse_Indirect = irradianceSH * baseColor.rgb*KD_IndirectLight;
                IndirectLight=Diffuse_Indirect+Specular_Indirect;

                FinalColor.rgb=DirectLight*attenuation+IndirectLight*ao;
                FinalColor.rgb=ACESToneMapping(FinalColor.rgb);
                //FinalColor.rgb=attenuation;

                return FinalColor;
            }
            ENDCG
        }
    }

    Fallback "Diffuse"
}
