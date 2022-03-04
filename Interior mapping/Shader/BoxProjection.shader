Shader "Unlit/BoxProjection"
{
    Properties
    {
        _Cube ("Reflection Cubemap", Cube) = "_Skybox" {}
        _EnvBoxStart ("Env Box Start", Vector) = (0, 0, 0)
        _EnvBoxSize ("Env Box Size", Vector) = (1, 1, 1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewDir:TEXCOORD1;
                float3 objectPos:TEXCOORD2;
            };


            samplerCUBE _Cube;
            float4 _Cube_ST;
            float4 _EnvBoxStart;
            float4 _EnvBoxSize;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float3 worldPos=mul(unity_ObjectToWorld,v.vertex).xyz;
                float3 worldViewDir=UnityWorldSpaceViewDir(worldPos);
                o.viewDir=-mul(unity_WorldToObject,float4(worldViewDir,0));
                o.objectPos=v.vertex.xyz;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewDir=i.viewDir;
                float3 objectPos=i.objectPos+half3(0.5,0.5,0);

                float3 rbmax=(_EnvBoxStart+_EnvBoxSize-objectPos)/viewDir;
                float3 rbmin=(_EnvBoxStart-objectPos)/viewDir;

                float3 t2=max(rbmin,rbmax);

                float fa=min(min(t2.x,t2.y),t2.z);
                float3 posNobox=objectPos+viewDir*fa;
                float3 reflectDir=posNobox-(_EnvBoxStart+_EnvBoxSize/2);

                fixed4 col = texCUBE(_Cube,reflectDir);
                return col;
            }
            ENDCG
        }
    }
}
