Shader "RealWater/PBR_Refractive_Tesselation"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		
		_NormalMap ("Simulation Map", 2D) = "bump" {}
		_NormalDetail ("Detail Map 1", 2D) = "bump" {}
		_NormalDetail2 ("Detail Map 2", 2D) = "bump" {}
		[Header(PBR Settings)]
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0

		//Refraction settings
		_RefMultMain("Simulation Refraction Mult", Range(0.1,2)) = 1
		_RefMultDetail("Detail Map Refraction Mult", Range(0.1,50)) = 1
		_Distortion  ("Refraction Distortion", range (0,256)) = 100

		//Tesselation settinga
		_EdgeLength ("Tessellation Factor", Range(1,50)) = 15
        _Displacement ("Tessellation Displacement", Range(-10.0, 10.0)) = 0.3

		//Detph settings
		_maxFog ("Max Depth Fog", Range(1,25)) = 25
		_maxFade("Max Depth Fade", Range(0,1)) = 0
		_depthScale("Depth Scaling",Range(1,25)) = 1

		//Aberration Settings
		_AberrationOffset("Aberration",Range(0.001,0.05)) = 1.0

		//Foam settings
		_FoamTex("Foam Texture(RGB)",2D) = "white" {}
		_FoamIntensity("Foam Intensity",Range(0.1,10)) = 2
    }

	SubShader
	{
		//Transparent in queue so that other objects drawn before this one.
		Tags {"Queue" = "Transparent" "RenderType"="Transparent" }
		
		Cull Off
		ZWrite Off
		LOD 300

			
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _GrabTexture
		GrabPass {
			Name "BASE"
			Tags { "LightMode" = "Always" }
		}
		
		//Refraction Pass
		Pass
		{
			Name "Refract"
			Tags{ "LightMode" = "Always" }

			CGPROGRAM
			#pragma multi_compile REFRACTION_ON REFRACTION_OFF
			#pragma multi_compile ABERRATION_ON ABERRATION_OFF

			
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
				float2 uvSim : TEXCOORD1;
				float2 uvmain : TEXCOORD2;
				float2 uvDetail1 : TEXCOORD3;
				float2 uvDetail2 : TEXCOORD4;
				UNITY_FOG_COORDS(5)
			};

			float _Distortion;
			float4 _NormalMap_ST;
			float4 _NormalDetail_ST;
			float4 _NormalDetail2_ST;
			 uniform float _AberrationOffset;

			v2f vert(appdata_t v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				#if REFRACTION_ON

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

					//Set up UV mapping for each texture					
					o.uvSim = TRANSFORM_TEX(v.texcoord, _NormalMap);
					o.uvDetail1 =  TRANSFORM_TEX(v.texcoord, _NormalDetail);
					o.uvDetail2 =  TRANSFORM_TEX(v.texcoord, _NormalDetail2); 
				
					UNITY_TRANSFER_FOG(o,o.vertex);
				#endif
				return o;
			}


			sampler2D _GrabTexture;
			float4 _GrabTexture_TexelSize;
			sampler2D _NormalMap;
			sampler2D _NormalDetail;
			sampler2D _NormalDetail2;
			float _RefMultDetail;
			float _RefMultMain;
		

			fixed4 frag(v2f i) : SV_Target
			{
				#if REFRACTION_ON
					// calculate perturbed coordinates
					half2 bump = _RefMultMain *UnpackNormal(tex2D(_NormalMap, i.uvSim)).rg; 
					half2 bump2 = _RefMultDetail * UnpackNormal(tex2D(_NormalDetail, i.uvDetail1)).rg; 
					half2 bump3 = _RefMultDetail * UnpackNormal(tex2D(_NormalDetail2, i.uvDetail2)).rg;
					half2 bumpCom = (bump  + bump2 + bump3);
					float2 offset = bumpCom * _Distortion * _GrabTexture_TexelSize.xy;

					#ifdef UNITY_Z_0_FAR_FROM_CLIPSPACE //to handle recent standard asset package on older version of unity (before 5.5)
						i.uvgrab.xy = offset * UNITY_Z_0_FAR_FROM_CLIPSPACE(i.uvgrab.z) + i.uvgrab.xy;
					#else
						i.uvgrab.xy = offset * i.uvgrab.z + i.uvgrab.xy;
					#endif

				#endif

				fixed4 col;

				#if ABERRATION_ON
				//	_AberrationOffset /= 300.0f;

					fixed4 red = tex2Dproj(_GrabTexture, i.uvgrab  - _AberrationOffset) ;
					fixed4 green = tex2Dproj(_GrabTexture, i.uvgrab) ;
					fixed4 blue = tex2Dproj(_GrabTexture, i.uvgrab + _AberrationOffset) ;

					col =  fixed4(red.r, green.g, blue.b, 1.0f); 

				#else
					col = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(i.uvgrab));
				#endif

                return col;
			}
	
			ENDCG


		}

		
		//#endif
	   
			
		CGPROGRAM
		#pragma multi_compile TESS_ON TESS_OFF 
		#pragma multi_compile DEPTH_ON DEPTH_OFF
		#pragma multi_compile FOAM_ON FOAM_OFF
		#pragma target 5.0
		#include "Tessellation.cginc"
		#include "UnityCG.cginc"
		#pragma surface surf Standard fullforwardshadows alpha:fade vertex:vert //vertex:disp tessellate:tessEdge 
			
		struct appdata 
		{
			float4 vertex : POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
			float2 texcoord2 : TEXCOORD2;
			float2 texcoor3 : TEXCOORD3;

		

		};

		sampler2D _MainTex;
		sampler2D _FoamTex;
		sampler2D _NormalMap;	
		sampler2D _NormalDetail;
		sampler2D _NormalDetail2;
		float _Displacement;
		float _FoamIntensity;
			
		void disp (inout appdata v)
		{
			#if TESS_ON
				float d = ((tex2Dlod( _NormalMap , float4(v.texcoord.xy ,0,0)).a - 0.5)) * _Displacement;
				v.vertex.xyz += v.normal * d;
			#endif
		}

		float _EdgeLength;
		float4 tessEdge (appdata v0, appdata v1, appdata v2)
		{
			#if TESS_ON
				return UnityEdgeLengthBasedTess (v0.vertex, v1.vertex, v2.vertex, _EdgeLength);
			#else

				float4 ret = {1,1,1,1};
				return ret;
		   #endif
		}
	
			 
		struct Input 
		{
			float2 uv_MainTex;
			float2 uv_FoamTex;
			float2 uv_NormalMap;
			float2 uv_NormalDetail;
			float2 uv_NormalDetail2;
			fixed facing : VFACE;
			 float4 screenPos;
            float eyeDepth;
			 float3 localPos;
		};
	 
		//Correctly combines two normal maps.
		inline fixed3 combineNormals (fixed3 nMap1, fixed3 nMap2) 
		{
			nMap1 += fixed3(0, 0, 1);
			nMap2 *= fixed3(-1, -1, 1);
			return (nMap1 * (dot(nMap1, nMap2) / nMap1.z) - nMap2);
		}
			
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		float _maxFog;
		float _maxFade;
		float _depthScale;

		 sampler2D_float _CameraDepthTexture;
        float4 _CameraDepthTexture_TexelSize;

		void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
			#if DEPTH_ON
				COMPUTE_EYEDEPTH(o.eyeDepth);
			#endif
        }
			
		void surf (Input IN, inout SurfaceOutputStandard o)
		{		
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			fixed4 foam = tex2D(_FoamTex, IN.uv_FoamTex);

		//	fixed4 c = (1+((tex2D (_NormalMap, IN.uv_NormalMap).g) - 0.5) * 20) * _Color;

			float waveHeight = min(1,_FoamIntensity * (abs((tex2D (_NormalMap, IN.uv_NormalMap).g) - 0.5)));

			/*
				MAYBE INSTEAF OF DIRECT WAVE HEIGHT PROPORTIONALUTY, HAVE IT SO FOAM ONLY IF HEIHGT ABOVE CUT OFF, THEN PROPORTIONAL WITHIN THAT RANGE

			*/

			#if FOAM_ON
				c = (1-waveHeight)*c + (waveHeight)*foam;
			#endif

            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
			#if FOAM_ON
				o.Metallic = _Metallic * (1-waveHeight);
				o.Smoothness = max(0.9,_Glossiness*(1-waveHeight));
			#else
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;
			#endif

			fixed3 normalSim = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
			fixed3 normalDetail1 = UnpackNormal(tex2D (_NormalDetail, IN.uv_NormalDetail));
			fixed3 normalDetail2 = UnpackNormal(tex2D (_NormalDetail2, IN.uv_NormalDetail2));

			o.Normal =  combineNormals(combineNormals(normalSim, normalDetail1), normalDetail2);


			float rawZ = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos));
			#if DEPTH_ON
				float sceneZ = LinearEyeDepth(rawZ);
				float partZ = IN.eyeDepth;
			#endif

            float fade = 1.0;
			#if DEPTH_ON
			  if ( rawZ > 0.0 ) // Make sure the depth texture exists
					fade = max(_maxFade, (min((sceneZ - partZ)/_depthScale,_maxFog)));
			#endif

				//Flip normals of backside of mesh
			if (IN.facing < 0.5)
			{
				#if DEPTH_ON
					#if FOAM_ON
							o.Alpha = 1/(1-waveHeight) * c.a * max(_maxFade, (min((partZ/_depthScale),_maxFog)));
					#else
						o.Alpha = c.a * max(_maxFade, (min((partZ/_depthScale),_maxFog)));
					#endif
				#endif
				o.Normal *= -1.0;
			}
			else
			{	
				#if FOAM_ON
					o.Alpha = c.a * fade * 1/(1-waveHeight);
				#else
						o.Alpha = c.a * fade;
				#endif
			}
			
		}
		ENDCG


		

	}
	FallBack "Standard"

	CustomEditor "RealWaterShaderEditor"

}
 