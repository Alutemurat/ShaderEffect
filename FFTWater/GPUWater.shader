Shader "Learn/GPUWater"
{
    Properties
    {
        _OceanColor ("Ocean Color",COLOR) = (1,1,1,1)
        _SpecualrColor ("Specular Color",COLOR) = (1,1,1,1)
        [HDR]_BubbleColor ("Bubble Color",COLOR) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Gloss("Gloss", Range(8,200)) = 1
        _DepthVisibility ("_Depth Visibility", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True"}
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            //Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos:TEXCOORD1;
                float4 screenPos:TEXCOORD2;
            };
            
            sampler2D _MainTex;
            sampler2D _Displace;
            sampler2D _Normal;
            float4 _MainTex_ST;
            fixed4 _BubbleColor;
            fixed4 _OceanColor;
            fixed4 _SpecualrColor;
            half _Gloss;
            half _DepthVisibility;

            sampler2D _CameraDepthTexture;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                float4 dispalce=tex2Dlod(_Displace,float4(o.uv,0,0));
                v.vertex+=float4(dispalce.xyz,0);
                o.worldPos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.vertex = UnityWorldToClipPos(o.worldPos);
                o.screenPos=ComputeScreenPos(o.vertex);
                COMPUTE_EYEDEPTH(o.screenPos.z);
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                float3 lightDir=normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 viewDir=normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 halfDir=normalize(lightDir+viewDir);
                float4 normalAndBubbles=tex2D(_Normal,i.uv);
                float3 normal=normalize(UnityObjectToWorldNormal(normalAndBubbles.xyz).rgb);

                float depth=SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos));
                float sceneZ=max(0,LinearEyeDepth(depth)- _ProjectionParams.g);
                float partZ=max(0,i.screenPos.z- _ProjectionParams.g);
                float depthGap = sceneZ - partZ;
                float x=clamp(depthGap/_DepthVisibility,0,1);
                
                half NdotL=saturate(dot(lightDir,normal));
                fixed3 diffuse = tex2D(_MainTex, i.uv).rgb*NdotL*_OceanColor.rgb;
                fixed3 bubbles=_BubbleColor.rgb*saturate(dot(lightDir,normal));
                diffuse=lerp(diffuse,bubbles,normalAndBubbles.a);
                fixed3 specular=_LightColor0.rgb*_SpecualrColor.rgb*pow(
                    max(0,dot(normal,halfDir)),_Gloss);

                fixed3 col=diffuse+specular;
                return fixed4(col,_OceanColor.a*x);
            }
            ENDCG
        }
    }
}
