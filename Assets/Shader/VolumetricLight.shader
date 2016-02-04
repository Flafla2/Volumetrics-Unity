Shader "Unlit/VolumetricLight"
{
	SubShader
	{
		Pass
		{
			ZTest Always Cull Off ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			struct v2f
			{
				// World space position of fragment
				float4 pos : SV_POSITION;
				// Clip space position of fragment
				half2 uv : TEXCOORD0;
				// World space direction of camera ray
				float4 cameraRay : TEXCOORD1;
			};

			uniform sampler2D ShadowMap;

			uniform float4x4 InverseProjectionMatrix;
			uniform float4x4 InverseViewMatrix;

			// Basic lighting data for the light being simulated.
			//
			// For point lights: 
			// xyz = light position
			// w = light radius
			//
			// For direction lights:
			// xyz = light direction, normalized
			// w = 0
			uniform float4 LightData;

			float RaymarchSteps;
			float ScatterFalloff;
			float ScatterIntensity;

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

			// Resource: https://interplayoflight.wordpress.com/2015/07/03/adventures-in-postprocessing-with-unity/
			v2f vert(appdata_img v)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;

				//transform clip pos to world space direction
				float4 clipPos = float4(v.texcoord * 2.0 - 1.0, 1.0, 1.0);
				float4 cameraRay_view = mul(InverseProjectionMatrix, clipPos);
				cameraRay_view = cameraRay_view / cameraRay_view.w;
				cameraRay_view.w = 0;
				o.cameraRay = normalize(mul(InverseViewMatrix, cameraRay_view));

				return o;
			}

			// Approximation of the Mie-scattering function (light scatter through large particles like aerosols)
			// Essentially light is scattered more in the forward direction than when viewed from the side.
			// We use the Henyey-Greenstein phase function to approximate this (as outlined in "GPU Pro 5", page 131)
			// 
			// Henyey-Greenstein function:
			// Let x = angle between light and camera vectors
			//     g = Mie scattering coefficient (ScatterFalloff)
			// f(x) = (1 - g)^2 / (4PI * (1 + g^2 - 2g*cos(x))^[3/2]
			float mie_scatter(in float3 light, in float3 cam) {

			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 p;
				float d;

				if (LightData.w) { // Point Light
					if (!intersect_ray_sphere(_WorldSpaceCameraPos, i.cameraRay, LightData.xyz, LightData.w, p, d))
						return fixed4(0, 0, 0, 0); // Ray does not intersect light volume
				}
				else
					return fixed4(0, 0, 0, 0); // Directional lights not yet supported.

				float step = d / RaymarchSteps;
				for (float m = 0; m <= d; m += step, p += i.cameraRay * step) {

				}
				
			}
			ENDCG
		}
	}
}
