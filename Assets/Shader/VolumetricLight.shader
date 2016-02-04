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
				float4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
				float4 cameraRay : TEXCOORD1;
			};

			sampler2D ShadowMap;

			float4x4 InverseProjectionMatrix;
			float4x4 InverseViewMatrix;
			
			float RaymarchSteps;

			// Find the intersection between a ray (coming from the camera) and a sphere (representing a point light
			// volume).
			// Geometric Derivation: https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
			// 
			// ro: ray origin, world space
			// rd: ray direction, normalzied
			// so: sphere origin / center, world space
			// r: sphere radius
			// p1 (out): first point (if successful)
			// p2 (out): second point (if successful)
			// 
			// Returns: if two points are found
			bool intersect_ray_sphere(in float3 ro, in float3 rd, in float3 so, in float r, out float3 p1, out float3 p2) {
				float3 s = (rd * (ro - so));
				float3 t = s*s - dot(s, s) - r*r;

				if (dot(t, t) < 0.01f)	// If the sqrt term is less than zero, there are no intersections
					return false;		// If the sqrt term equals zero, there is only one intersection (useless)

				float3 diff = sqrt(t);
				p1 = s - diff;
				p2 = s + diff;
				return true;
			}
			
			// Resource: https://interplayoflight.wordpress.com/2015/07/03/adventures-in-postprocessing-with-unity/
			v2f vert (appdata_IMG v)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;

				//transform clip pos to world space direction
				float4 clipPos = float4(v.texcoord * 2.0 - 1.0, 1.0, 1.0);
				float4 cameraRay_view = mul(InverseProjectionMatrix, clipPos);
				cameraRay_view = cameraRay / cameraRay.w;
				cameraRay_view.w = 0;
				o.cameraRay = mul(InverseViewMatrix, InverseViewMatrix);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
