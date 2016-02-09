Shader "Unlit/VolumetricLight"
{
	SubShader
	{

CGINCLUDE
#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityDeferredLibrary.cginc"

#define PI 3.14159

uniform sampler2D ShadowMap;

// Basic lighting data for the light being simulated.
//
// For point lights: 
// xyz = light position
// w = light radius
uniform float4 LightData;
uniform float3 LightColor;

uniform float RaymarchSteps;
uniform float ScatterFalloff;
uniform float ScatterIntensity;

// Light cascade 
uniform float4 LightSplitsNear;
uniform float4 LightSplitsFar;

// Find the intersection between a ray (coming from the camera) and a sphere (representing a point light
// volume).  Bails out and doesn't return anything if only one or no intersection points are found.
// Geometric Derivation: https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
// 
// ro: ray origin, world space
// rd: ray direction, normalzied
// so: sphere origin / center, world space
// r: sphere radius
// p (out): first intersection point (if successful)
// d (out): distance between  (if successful)
// 
// Returns: if two points are found
bool intersect_ray_sphere(in float3 ro, in float3 rd, in float3 so, in float r, out float3 p, out float d) {
	float3 s = (rd * (ro - so));
	float3 t = s*s - dot(s, s) - r*r;

	if (dot(t, t) < 0.01f)	// If the sqrt term is less than zero, there are no intersections
		return false;		// If the sqrt term equals zero, there is only one intersection (useless)

	float3 diff = sqrt(t);
	d = length(2 * diff);
	p = s - diff;
	//p2 = s + diff;
	return true;
}

// Approximation of the Mie-scattering function (light scatter through large particles like aerosols)
// Essentially light is scattered more in the forward direction than when viewed from the side.
// We use the Henyey-Greenstein phase function to approximate this (as outlined in "GPU Pro 5", page 131)
// 
// Henyey-Greenstein function:
// Let x = angle between light and camera vectors
//     g = Mie scattering coefficient (ScatterFalloff)
// f(x) = (1 - g)^2 / (4PI * (1 + g^2 - 2g*cos(x))^[3/2])
float mie_scatter(in float3 light, in float3 cam) {
	float n = 1 - ScatterFalloff; // 1 - g
	float c = dot(light,cam); // cos(x)
	float d = 1 + ScatterFalloff * ScatterFalloff - 2*ScatterFalloff*c; // 1 + g^2 - 2g*cos(x)
	return n * n / (4 * PI * pow(d, 1.5))
}

// Resource: https://interplayoflight.wordpress.com/2015/07/03/adventures-in-postprocessing-with-unity/
fixed4 CalculateLight (unity_v2f_deferred i) : SV_Target
{
	float3 p;
	float d;

	if (!intersect_ray_sphere(_WorldSpaceCameraPos, i.ray, LightData.xyz, LightData.w, p, d))
		return fixed4(0, 0, 0, 0); // Ray does not intersect light volume

	float STEP = d / RaymarchSteps;
	float4 total = float4(0,0,0,0);

	float4 viewZ = -viewPos.z;
	float4 zNear = float4( viewZ >= _LightSplitsNear );
	float4 zFar = float4( viewZ < _LightSplitsFar );
	float4 weights = zNear * zFar;

	for (float m = 0; m <= d; m += STEP, p += i.ray * STEP) {
		float3 lightDir = normalize(p - LightData.xyz);
		float scatter = mie_scatter(lightDir, i.ray) * ScatterIntensity;

		float3 shadowCoord0 = mul(unity_World2Shadow[0], float4(currentPos,1)).xyz;
	    float3 shadowCoord1 = mul(unity_World2Shadow[1], float4(currentPos,1)).xyz;
	    float3 shadowCoord2 = mul(unity_World2Shadow[2], float4(currentPos,1)).xyz;
	    float3 shadowCoord3 = mul(unity_World2Shadow[3], float4(currentPos,1)).xyz;
	
	    float4 shadowCoord = float4(shadowCoord0 * weights[0] + shadowCoord1 * weights[1] + shadowCoord2 * weights[2] + shadowCoord3 * weights[3],1);
	}
	
}
ENDCG

Pass
{
	Fog { Mode Off }
	ZWrite Off
	ZTest Always
	Blend One One
	Cull Front

	CGPROGRAM
	#pragma target 3.0
	#pragma vertex vert
	#pragma fragment frag
	#pragma exclude_renderers nomrt

	unity_v2f_deferred vert (float4 vertex : POSITION)
	{
		unity_v2f_deferred o;
		o.pos = mul(UNITY_MATRIX_MVP, vertex);
		o.uv = ComputeScreenPos (o.pos);
		o.ray = mul (UNITY_MATRIX_MV, vertex).xyz * float3(-1,-1,1);
		return o;
	}


	half4 frag (unity_v2f_deferred i) : SV_Target
	{
		return CalculateLight(i);
	}


	ENDCG
}

}
Fallback Off
}
