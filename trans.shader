﻿Shader "RealWater/PBR_Refractive_Tesselation"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalMap ("Simulation Map", 2D) = "bump" {}
		_NormalDetail ("Detail Map 1", 2D) = "bump" {}
		_NormalDetail2 ("Detail Map 2", 2D) = "bump" {}
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0

		_RefMult("Refraction Detail Map Multiplier", Range(1,50)) = 1
		_Distortion  ("Distortion", range (0,256)) = 100
        _Tess ("Tessellation", Range(1,100)) = 4
        _Displacement ("Displacement", Range(-10.0, 10.0)) = 0.3
    }
	
	Category 
	{
		//Transparent in queue so that other objects drawn before this one.
		 Tags {"Queue" = "Transparent" "RenderType"="Transparent" }
	
		SubShader
		{
			Cull Off
			ZWrite Off
			LOD 300
			
			// This pass grabs the screen behind the object into a texture.
			// We can access the result in the next pass as _GrabTexture
			GrabPass {
				Name "BASE"
				Tags { "LightMode" = "Always" }
			}
		
		
			Pass
			{
				Name "Refract"
				Tags{ "LightMode" = "Always" }

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fog
				#include "UnityCG.cginc"

				struct appdata_t {
					float4 vertex : POSITION;
					float2 texcoord: TEXCOORD0;
				};

				struct v2f {
					float4 vertex : SV_POSITION;
					float4 uvgrab : TEXCOORD0;
					float2 uvbump : TEXCOORD1;
					float2 uvmain : TEXCOORD2;
					UNITY_FOG_COORDS(3)
				};

				float _Distortion;
				float4 _Normal_ST;
				float4 _NormalDetail_ST;
				float4 _NormalDetail2_ST;
				float4 _MainTex_ST;


				v2f vert(appdata_t v)
				{
					v2f o;
					#if UNITY_VERSION >= 540
					o.vertex = UnityObjectToClipPos(v.vertex);
					#else
					o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
					#endif
					#if UNITY_UV_STARTS_AT_TOP
					float scale = -1.0;
					#else
					float scale = 1.0;
					#endif
					o.uvgrab.xy = (float2(o.vertex.x, o.vertex.y*scale) + o.vertex.w) * 0.5;
					o.uvgrab.zw = o.vertex.zw;
					o.uvbump =  TRANSFORM_TEX(v.texcoord, _NormalDetail) + TRANSFORM_TEX(v.texcoord, _NormalDetail2); //TRANSFORM_TEX(v.texcoord, _Normal) +
					o.uvmain = TRANSFORM_TEX(v.texcoord, _MainTex);
					UNITY_TRANSFER_FOG(o,o.vertex);
					return o;
				}

				sampler2D _GrabTexture;
				float4 _GrabTexture_TexelSize;
				sampler2D _NormalMap;
				sampler2D _NormalDetail;
				sampler2D _NormalDetail2;

				sampler2D _MainTex;
				float2 none = (0, 0);
				fixed4 _Color;
				float _RefMult;

				half4 frag(v2f i) : SV_Target
				{
					// calculate perturbed coordinates
					half2 bump = UnpackNormal(tex2D(_NormalMap, i.uvmain)).rg; // we could optimize this by just reading the x & y without reconstructing the Z
					half2 bump2 = _RefMult * UnpackNormal(tex2D(_NormalDetail, i.uvbump)).rg; // we could optimize this by just reading the x & y without reconstructing the Z
					half2 bump3 = _RefMult * UnpackNormal(tex2D(_NormalDetail2, i.uvbump)).rg;
					
					half2 bumpCom = (bump + bump2 + bump3);
					float2 offset = bumpCom * _Distortion * _GrabTexture_TexelSize.xy;
					#ifdef UNITY_Z_0_FAR_FROM_CLIPSPACE //to handle recent standard asset package on older version of unity (before 5.5)
						i.uvgrab.xy = offset * UNITY_Z_0_FAR_FROM_CLIPSPACE(i.uvgrab.z) + i.uvgrab.xy;
					#else
						i.uvgrab.xy = offset * i.uvgrab.z + i.uvgrab.xy;
					#endif

					half4 col = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(i.uvgrab));
					half4 tint;
					return col;
				}
				
				ENDCG
		}
	   
			
			CGPROGRAM
			
			#pragma target 5.0
			#include "Tessellation.cginc"
			#include "UnityCG.cginc"
			
	 
			//Edge Based
			//#pragma surface surf Standard fullforwardshadows alpha:fade vertex:disp tessellate:tessEdge
			
			//Distance Based
			#pragma surface surf Standard fullforwardshadows alpha:fade vertex:disp tessellate:tessDistance

			struct appdata 
			{
				float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float2 texcoord2 : TEXCOORD2;
			};

			sampler2D _MainTex;
			sampler2D _NormalMap;	
			sampler2D _NormalDetail;
			sampler2D _NormalDetail2;
			float _Displacement;
			
			void disp (inout appdata v)
			{
				float d = ((tex2Dlod( _NormalMap , float4(v.texcoord.xy ,0,0)).a - 0.5)) * _Displacement;
				v.vertex.xyz += v.normal * d;
			}
			
			//Distance based	
			float _Tess;
			
			float4 tessDistance (appdata v0, appdata v1, appdata v2) 
			{
				float minDist = 10;
				float maxDist = 30.0;
				return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _Tess);
			}

			//Edge Based
			//float _EdgeLength;
			//float4 tessEdge (appdata v0, appdata v1, appdata v2)
			//{
			//   return UnityEdgeLengthBasedTess (v0.vertex, v1.vertex, v2.vertex, _EdgeLength);
			//}
			   

			struct Input 
			{
				float2 uv_MainTex;
				float2 uv_NormalMap;
				float2 uv_NormalDetail;
				float2 uv_NormalDetail2;
				fixed facing : VFACE;
			};
	 
			inline fixed3 combineNormalMaps (fixed3 base, fixed3 detail) 
			{
				base += fixed3(0, 0, 1);
				detail *= fixed3(-1, -1, 1);
				return base * dot(base, detail) / base.z - detail;
			}
			
			half _Glossiness;
			half _Metallic;
			fixed4 _Color;
			
			void surf (Input IN, inout SurfaceOutputStandard o)
			{		
				fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
				o.Albedo = c.rgb;			
				
				fixed3 BaseNormal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
				fixed3 DetailNormal1 = UnpackNormal(tex2D (_NormalDetail, IN.uv_NormalDetail));
				fixed3 DetailNormal2 = UnpackNormal(tex2D (_NormalDetail2, IN.uv_NormalDetail2));

				o.Normal =  combineNormalMaps(combineNormalMaps(BaseNormal, DetailNormal1), DetailNormal2 );

				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;
				o.Alpha = c.a;		
				
				//Flip normals of backside of mesh
				if (IN.facing < 0.5)
					o.Normal *= -1.0;
				
			}


			
			ENDCG
		}
		FallBack "Standard"
	}
}
 