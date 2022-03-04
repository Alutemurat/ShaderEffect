Shader "MyShader/InteriorMappingTest"
{
    Properties
    {
        _WallTexA("Wall Texture A",2D)="white"{}
        _WallTexB("Wall Texture B",2D)="white"{}
        _RoofTex ("Texture", 2D) = "white" {}
        _FloorTex("Floor Texture",2D)="white"{}
        _Distance("Distance",Float)=0.2
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
            
            sampler2D _WallTexA;
            sampler2D _WallTexB;
            sampler2D _RoofTex;
            sampler2D _FloorTex;
            float _Distance;
            
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

            static float3 up=float3(0,1,0);
            static float3 right=float3(1,0,0);
            static float3 forward=float3(0,0,1);

            float2 getUV(float3 pos,float3 dir)
            {
                return pos.xy*dir.z+pos.xz*dir.y+pos.zy*dir.x;
            }

            half3 intersectPlane(float3 dir,float3 rd,float4 ro,sampler2D texA,sampler2D texB,half3 baseCol, inout float t)
            {
                float t0=0;

                if(dot(dir,rd)>0)
                {
                    float3 wallPos=ceil(ro.w/_Distance)*_Distance*dir;
                    t0=dot(wallPos-ro.xyz,dir)/dot(rd,dir);
                    if(t0<t)
                    {
                        t=t0;
                        
                        float3 pos=ro+rd*t0;
                        pos=pos/_Distance;

                        baseCol=tex2D(texA,getUV(pos,dir));
                    } 
                }
                else
                {
                    
                    float3 wallPos=(ceil(ro.w/_Distance)-1)*_Distance*dir;
                    t0=dot(wallPos-ro.xyz,dir)/dot(rd,dir);
                    if(t0<t)
                    {
                        t=t0;

                        float3 pos=ro+rd*t0;
                        pos=pos/_Distance;

                        baseCol=tex2D(texB,getUV(pos,dir));
                    } 
                }
                return baseCol;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rd=normalize(i.viewDir);
                float3 ro=i.objectPos-float3(0.5,0.5,0)+rd*0.001;

                float t=10000;
                half4 col=1;

                col.rgb=intersectPlane(up,rd,float4(ro,ro.y),_RoofTex,_FloorTex,col.rgb,t);
                col.rgb=intersectPlane(right,rd,float4(ro,ro.x),_WallTexA,_WallTexA,col.rgb,t);
                col.rgb=intersectPlane(forward,rd,float4(ro,ro.z),_WallTexB,_WallTexB,col.rgb,t);

                return col;
            }
            ENDCG
        }
    }
}
