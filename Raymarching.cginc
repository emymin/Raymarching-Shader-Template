#include "RaymarchingUtils.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityLightingCommon.cginc"

//GENERAL SHADER OPTIONS
#define WORLDSPACE 0
#define LIGHTING 1
#define SHADOWS 1 //doesn't do much, to disable shadows, comment out the line UsePass "Raymarching/RayMarchShadowCast/ShadowCast" in the main shader
#define OCCLUSION 1
#define BACKGROUND 0
#define INSIDE_COLOR 1

//RAYMARCH OPTIONS
#define MAX_STEPS 100
#define SURF_DIST 1e-3
#define MAX_DIST 1e15
            

float GetPosHitpos(float4 vertex, out float3 cameraPos,out float3 hitPos){
    #if WORLDSPACE
    cameraPos = _WorldSpaceCameraPos;
    hitPos = mul(unity_ObjectToWorld, vertex);
    #else
    cameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1));
    hitPos=vertex;
    #endif
    return 0;
}



//DISTANCE FUNCTION
//==========================
float GetDist(float3 p) {
    float d = sdSphere(p,0.5);
    //d = sdCone(p,1,0.5);
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
    p=mul(unity_ObjectToWorld,p);
    n=UnityObjectToWorldNormal(n);
    #endif
    

    float3 lightVec = p-lightPos;
    float3 lightDir = normalize(lightVec);

    float light = saturate(dot(n,lightPos.xyz));
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

float DepthFromPos(float3 p,float d){
    float depth;
    #if WORLDSPACE
    p=mul(unity_WorldToObject,float4(p,1));
    #endif
    
    #if OCCLUSION
    depth=getDepth(p);
    if(d<0) depth=1;
    #else
    depth=1;
    #endif

    return depth;
}