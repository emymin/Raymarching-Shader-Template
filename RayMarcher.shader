Shader "RayMarching/RayMarcher"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
    #include "Raymarching.cginc"
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" } //Overlay-1 if transparent
        LOD 100
        //ZTest Always
        //ZWrite Off
        Cull Off

        //main pass, renders color and depth
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "UnityLightingCommon.cginc"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 cameraPos : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
                float4 scrPos : TEXCOORD3;
            };
            struct fragOutput
            {
                fixed4 color : SV_Target;
                float depth : SV_Depth;
            };

            
            sampler2D _MainTex;
			float4 _MainTex_ST;
            sampler2D _CameraDepthTexture;

            v2f vert (appdata v)
            {
                v2f o;
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                GetPosHitpos(v.vertex,o.cameraPos,o.hitPos);
                o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            fragOutput frag (v2f i) //: SV_Target
            {
                fragOutput o;

                float4 col;
                float4 scrPos=i.scrPos;

                float3 ro = i.cameraPos;
                float3 ray = (i.hitPos-i.cameraPos);
                float3 rd=normalize(ray);
                float d = Raymarch(ro,rd);
                float3 p = ro + d * rd;

                //depth occlusion without writing to Zbuffer, in case you want something transparent
                /*#if OCCLUSION
                float depth = (tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(scrPos)));
                depth = LinearEyeDepth(depth);
                ray=mul(unity_ObjectToWorld,ray);
                depth /= dot(normalize(ray),mul(unity_ObjectToWorld,GetCameraForward()));
                if(depth<d){discard;}
                #endif*/

                if(d<MAX_DIST){
                    
                    float3 n = GetNormal(p);
                    float2 uv = GetUV(p,n);
                    col = GetColorUV(uv);
                    
                    col.rgb=CalculateLighting(p,n,col.rgb);

                    #if INSIDE_COLOR
                    if(d<0){
                        col=GetInsideColor(p);
                    }
                    #endif

                } else {
                    #if !BACKGROUND
                    discard;
                    #else
                    col=GetBackground(rd);
                    #endif
                }

                o.color=col;
                o.depth=DepthFromPos(p,d);

                return o;
            }

            

            ENDCG
        }
        
        //UsePass "Raymarching/RayMarchShadowCast/ShadowCast"

    }
}
