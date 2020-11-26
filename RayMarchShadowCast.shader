Shader "Raymarching/RayMarchShadowCast"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {"LightMode"="ShadowCaster"}
            Name "ShadowCast"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            #include "Raymarching.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
                float3 cameraPos : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };
            
            struct frag_o {
                float depth : SV_Depth;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                GetPosHitpos(v.vertex,o.cameraPos,o.hitPos);
                return o;
            }

            frag_o frag(v2f i)
            {
                frag_o o;
                
                float3 ro = i.cameraPos;
                float3 ray = (i.hitPos-i.cameraPos);
                float3 rd=normalize(ray);
                float d = Raymarch(ro,rd);
                float3 p = ro + d * rd;

                /*float4 opos = mul(unity_WorldToObject, float4(p, 1.0));
                float3 worldNormal = normalize(p);
                opos = UnityClipSpaceShadowCasterPos(opos, worldNormal);*/
                o.depth=DepthFromPos(p,d);
                return o;
            }
            ENDCG
        }
    }
}
