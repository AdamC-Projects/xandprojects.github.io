// This defines a simple unlit Shader object that is compatible with a custom Scriptable Render Pipeline.
// It applies a hardcoded color, and demonstrates the use of the LightMode Pass tag.
// It is not compatible with SRP Batcher.

Shader"Shadow/ShadowVolume"
{
Properties
{
    _Colour ("Colour", Color) = (0.5, 1, 0.5, 1)
}

HLSLINCLUDE

struct Attributes
{
    float4 vertex : POSITION;
    float4 normal : NORMAL;
};

struct Varyings
{
    float4 pos : SV_POSITION;
    float3 normal : TEXCOORD0;
};

#include "Assets/ShaderIncludes/UnityShaderUtilities.cginc"
#include "Assets/ShaderIncludes/Helpers/CRPHelper.cginc"
#include "Assets/ShaderIncludes/LightStructs.cginc"

StructuredBuffer<DirectionalLightData> _DirectionalLights;
int _DirectionalLightsCount;
StructuredBuffer<PointLightData> _PointLights;
int _PointLightsCount;

Varyings shadowVert(Attributes v)
{
    Varyings o;
    o.pos = v.vertex;
    o.normal = UnityObjectToWorldNormal(v.normal.xyz);
    return o;
}

[maxvertexcount(3)]
void shadowGeom(triangle Varyings i[3], inout TriangleStream<Varyings> stream)
{
    int j;
    for (int k = 0; k < _DirectionalLightsCount; k++)
        for (j = 0; j < 3; ++j)
        {
            Varyings o;
            o = i[j];
            if (dot(_DirectionalLights[k].direction, o.normal) > 0)
                o.pos = mul(UNITY_MATRIX_VP, float4(_DirectionalLights[k].direction, _ProjectionParams.w));
            else
                o.pos = mul(UNITY_MATRIX_VP, mul(unity_ObjectToWorld, o.pos) + 0.01 * float4(_DirectionalLights[k].direction - o.normal, 0));
            stream.Append(o);
        }
    for (k = 0; k < _PointLightsCount; k++)
        for (j = 0; j < 3; ++j)
        {
            Varyings o;
            o = i[j];
            float4 worldPos = mul(unity_ObjectToWorld, o.pos);
            float3 dir = normalize(worldPos.xyz - _PointLights[k].worldPos);
            if (dot(dir, o.normal) > 0)
                o.pos = mul(UNITY_MATRIX_VP, float4(dir, _ProjectionParams.w));
            else
                o.pos = mul(UNITY_MATRIX_VP, worldPos + 0.01 * float4(dir - o.normal, 0));
            stream.Append(o);
        }
}

float4 shadowFrag(Varyings i) : SV_Target
{
    return 0;
}

ENDHLSL

SubShader
{

Pass
{

Stencil
{
    Pass Zero
}

// The value of the LightMode Pass tag must match the ShaderTagId in ScriptableRenderContext.DrawRenderers
Tags { "LightMode" = "ExampleLightModeTag" "Layers" = "DeferredTest" }
            
HLSLPROGRAM

#pragma vertex vert
#pragma fragment frag

//float4x4 unity_MatrixVP;
//float4x4 unity_ObjectToWorld;

CBUFFER_START(UnityPerMaterial)   
             
uniform float4 _Colour;

CBUFFER_END


struct PixelData
{
    float4 colour : CRP_Target_COLOUR;
    float2 normal : CRP_Target_NORMAL;
    float layer : CRP_Target_LAYER;
};

Varyings vert(Attributes v)
{
    Varyings o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.normal = COMPUTE_VIEW_NORMAL(v.normal);
    return o;
}

PixelData frag(Varyings i)
{
    PixelData o;
    o.colour = _Colour;
    o.normal = EncodeNormal(normalize(i.normal));; //float4(i.normal, 0);
    uint layer = Layer_DeferredTest;
    o.layer = EncodeUintToFloat(layer);
    return o;
}

ENDHLSL
}

Pass
{
    ZWrite Off Cull Front ColorMask 0

    Stencil
    {
        ZFail IncrWrap
    }


    Tags { "LightMode" = "ShadowFront" }
                
    HLSLPROGRAM

        #pragma vertex shadowVert
        #pragma geometry shadowGeom
        #pragma fragment shadowFrag

    ENDHLSL
}

Pass
{
    ZWrite Off Cull Back ColorMask 0

    Stencil
    {
        ZFail DecrWrap
    }


    Tags { "LightMode" = "ShadowBack" }
            
    HLSLPROGRAM

        #pragma vertex shadowVert
        #pragma geometry shadowGeom
        #pragma fragment shadowFrag

    ENDHLSL
}

Pass
{
ZWrite Off

Stencil
{
    Ref 0
    Comp NotEqual
}


Tags { "LightMode" = "ShadowWrite" "Layers" = "DeferredShadow" }
            
HLSLPROGRAM

#pragma vertex vert
#pragma fragment frag

struct PixelData2
{
    float4 layer : CRP_Target_LAYER;
};

struct Attributes2
{
    float4 vertex : POSITION;
};

struct Varyings2
{
    float4 pos : SV_POSITION;
};


Varyings2 vert(Attributes2 v)
{
    Varyings2 o;
    o.pos = UnityObjectToClipPos(v.vertex);
    return o;
}

PixelData2 frag(Varyings2 i)
{
    PixelData2 o;
    uint layer = Layer_DeferredShadow;
    o.layer = EncodeUintToFloat(layer);
    return o;
}

ENDHLSL
}
}}