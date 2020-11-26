Shader "RayMarching/RayMarcher"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
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

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "UnityLightingCommon.cginc"
            #include "RaymarchingUtils.cginc"

            //GENERAL SHADER OPTIONS
            #define WORLDSPACE 0
            #define LIGHTING 1
            #define SHADOWS 0
            #define OCCLUSION 1
            #define BACKGROUND 0
            #define INSIDE_COLOR 1
            
            //RAYMARCH OPTIONS
            #define MAX_STEPS 100
            #define SURF_DIST 1e-3
            #define MAX_DIST 1e15
            

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
                #if WORLDSPACE
                float3 pos = _WorldSpaceCameraPos;
                float3 hitPos = mul(unity_ObjectToWorld, v.vertex);
                #endif
                #if !WORLDSPACE
                float3 pos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1));
                float3 hitPos=v.vertex;
                #endif
                o.cameraPos = pos;
                o.hitPos=hitPos;
                o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            //DISTANCE FUNCTION
            //==========================
            float GetDist(float3 p) {
                float d = sdSphere(p,0.5);
				return d;
			}
            //===========================

            float3 GetNormal(float3 p) {
				float2 e = float2(1e-2, 0);

				float3 n = GetDist(p) - float3(
					GetDist(p-e.xyy),
					GetDist(p-e.yxy),
					GetDist(p-e.yyx)
				);

				return normalize(n);
			}

			float Raymarch(float3 ro, float3 rd) {
				float dO = 0;
				float dS;
				for (int i = 0; i < MAX_STEPS; i++) {
					float3 p = ro + rd * dO;
					dS = GetDist(p);
					dO += dS;
					if (dS<SURF_DIST || dO>MAX_DIST) break;
				}
				return dO;
			}
            
            //COLORING FUNCTIONS
            //=====================
            float2 GetUV(float3 p,float3 n){
                return SphereUV(n);
            }

            float4 GetColorUV(float2 uv){
                return CheckerBoard(uv,10);
            }

            float4 GetColor(float3 p,float3 n){
                return float4(n,1);
            }
            
            float4 GetBackground(float3 direction){
                return UNITY_SAMPLE_TEXCUBE(unity_SpecCube0,direction);
            }

            float4 GetInsideColor(float3 p){
                return float4(0,0,0,1);
            }

            //LIGHTING
            //====================

            float3 LightColor(float3 p,float3 n,float3 lightPos,float3 lightColor,float attenuation){
                
                #if !WORLDSPACE
                lightPos=mul(unity_WorldToObject,float4(lightPos,1));
                #endif
                

                float3 lightVec = p-lightPos;
                float3 lightDir = normalize(lightVec);

                float light = saturate(dot(n,lightPos));
                light/=1+attenuation*dot(lightVec,lightVec);

                return lightColor*light;
            }

            float3 CalculateLighting(float3 p,float3 n,float3 col){
                
                float3 lightColor=1;
                
                #if LIGHTING
                lightColor=0;

                float3 lightPos=_WorldSpaceLightPos0;
                lightColor+=LightColor(p,n,lightPos,_LightColor0,1);
                
                /*float fac;
                for(int i=0;i<4;i++){
                    lightPos=(unity_4LightPosX0[i], unity_4LightPosY0[i], unity_4LightPosZ0[i]);
                    lightColor+=LightColor(p,n,lightPos,unity_LightColor[i],unity_4LightAtten0[i]);
                }*/
                
                lightColor+=ShadeSH9(half4(n,1));

                #endif

                return lightColor*col;
            }
            
            //FRAG
            //======================

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
                    #endif
                    #if BACKGROUND
                    col=GetBackground(rd);
                    #endif
                }

                o.color=col;
                

                #if WORLDSPACE
                p=mul(unity_WorldToObject,float4(p,1));
                #endif
                #if OCCLUSION
                o.depth=getDepth(p);
                if(d<0) o.depth=1;
                #endif
                #if !OCCLUSION
                o.depth=1;
                #endif
                return o;
            }

            ENDCG
        }
    }
}
