Shader "RealWater/PBR_Refractive_Tesselation"
{
    Properties
    {
        _Color ("Tint Colour", Color) = (1,1,1,1)
        _MainTex ("Tint Texture (RGB)", 2D) = "white" {}
		_NormalMap ("Simulation Map", 2D) = "bump" {}
		_NormalDetail ("Detail Map 1", 2D) = "bump" {}
		_NormalDetail2 ("Detail Map 2", 2D) = "bump" {}

		[Header(PBR Settings)]
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0

		[Header(Refraction Settings)]
		[Toggle(REFRACTION)]
        _REFRACTION ("Enable Refraction", Float) = 1
		_RefMultMain("Simulation Refraction Mult", Range(0.1,2)) = 1
		_RefMultDetail("Detail Map Refraction Mult", Range(0.1,50)) = 1
		_Distortion  ("Refraction Distortion", range (0,256)) = 100

		[Header(Tessellation Settings)]
		[Toggle(TESSELLATION)]
		TESSELATION ("Enable Tessellation", Float) = 1
		_EdgeLength ("Tessellation Factor", Range(1,50)) = 15
        _Displacement ("Tessellation Displacement", Range(-5.0, 5.0)) = 1.5

		[Header(Depth Settings)]
		[Toggle(DEPTH_FOG)]
		DEPTH_FOG ("Enable Depth Effects", Float) = 1
		_maxFog ("Max Depth Fog Multiplier", Range(1,10)) = 10
		_maxFade("Max Depth Fade Multiplier", Range(0,1)) = 0
		_depthScale("Depth Scaling Factor",Range(0.1,25)) = 1

		[Header(Aberration Settings)]
		[Toggle(ABERRATION)]
		ABERRATION ("Enable Chromatic Aberration", Float) = 0
		_AberrationOffset("Aberration Level",Range(0.001,0.05)) = 1.0

		[Header(Wave Foam Settings)]
		[Toggle(FOAM)]
		FOAM ("Enable Wave Foam", Float) = 0
		_FoamTex("Foam Texture(RGB)",2D) = "white" {}
		_FoamIntensity("Foam Intensity", Range(0.1,10)) = 2
		_FoamCuttoff("Foam Height Cuttoff", Range(0,0.1)) = 0
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
		
		//Refraction and Aberration Pass
		Pass
		{
			Name "Refract"
			Tags{ "LightMode" = "Always" }

			CGPROGRAM
            #pragma shader_feature REFRACTION
			#pragma shader_feature ABERRATION

			
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
				#if defined(REFRACTION) || defined(ABERRATION)

					//Unity handles this diffently depending on the editor version
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

					#ifdef REFRACTION
						//Set up UV mapping for each texture					
						o.uvSim = TRANSFORM_TEX(v.texcoord, _NormalMap);
						o.uvDetail1 =  TRANSFORM_TEX(v.texcoord, _NormalDetail);
						o.uvDetail2 =  TRANSFORM_TEX(v.texcoord, _NormalDetail2); 
					#endif
				
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
			
				fixed4 col;

				#ifdef REFRACTION
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

				#ifdef ABERRATION
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


		//Standard shader pass. In this surface shader depth fog, wave foam and tesselation are applied
		CGPROGRAM
        #pragma shader_feature TESSELLATION
		#pragma shader_feature DEPTH_FOG
		#pragma shader_feature FOAM
		#pragma target 5.0
		#pragma surface surf Standard fullforwardshadows alpha:fade vertex:disp tessellate:tessEdge 
		#include "Tessellation.cginc"
		#include "UnityCG.cginc"

		static const float TESS_MAX = 50; //Should be set to the max of the _EdgeLength range
			
		struct appdata 
		{
			float4 vertex : POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
			float2 texcoord2 : TEXCOORD2;
			float2 texcoor3 : TEXCOORD3;

			//Due to limitations with using custom vert outputs with unity's built in tesselation shader
			//We use the COLOR input semantic to pass in the extra data needed for depth fog calculations.
			fixed4 color : COLOR;

		};

		sampler2D _MainTex;
		sampler2D _FoamTex;
		sampler2D _NormalMap;	
		sampler2D _NormalDetail;
		sampler2D _NormalDetail2;
		float _Displacement;
		float _FoamIntensity;

		//Calculates tesselation and vertex depth data			
		void disp (inout appdata v)
		{
			//Compute eye depth and store in color semantic.
			#ifdef DEPTH_FOG
				COMPUTE_EYEDEPTH(v.color.r);
			#endif

			#ifdef TESSELLATION
				float d = ((tex2Dlod( _NormalMap , float4(v.texcoord.xy ,0,0)).a - 0.5)) * _Displacement;
				v.vertex.xyz += v.normal * d;
			#endif
		}

		//Applies tesselation
		float _EdgeLength;
		float4 tessEdge (appdata v0, appdata v1, appdata v2)
		{
			#ifdef TESSELLATION
				return UnityEdgeLengthBasedTess (v0.vertex, v1.vertex, v2.vertex, TESS_MAX - _EdgeLength);
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
			float3 localPos;
			float4 color : COLOR;
		};
	 
		//Correctly combines two normal maps.
		inline fixed3 combineNormals (fixed3 nMap1, fixed3 nMap2) 
		{
			nMap1 += fixed3(0, 0, 1);
			nMap2 *= fixed3(-1, -1, 1);
			return (nMap1 * (dot(nMap1, nMap2) / nMap1.z) - nMap2);
		}
		
		//Shader properties	
		half _Smoothness;
		half _Metallic;
		fixed4 _Color;
		float _maxFog;
		float _maxFade;
		float _depthScale;
		float _FoamCuttoff;

		//Used im depth effects
		sampler2D_float _CameraDepthTexture;
        float4 _CameraDepthTexture_TexelSize;
			
		void surf (Input IN, inout SurfaceOutputStandard o)
		{		
			//Multiplier used in applying foam
			float foamMultiplier = 1;

			//Multipliers applied to alpha channel to create depth effects. Does nothing if depth effects not enabled.
			float depthMultiplier = 1.0;
			float depthMultiplierFlip = 1.0;

			//Read in main texture
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;

			//Set up foam effect variables
			#ifdef FOAM
				//Read in foam texture
				fixed4 foam = tex2D(_FoamTex, IN.uv_FoamTex);

				//The value of the simulation map at this pixel position.
				float val = (abs((tex2D (_NormalMap, IN.uv_NormalMap).g) - 0.5));

				//Only blend in areas above the cuttof
				if(abs(val) >= _FoamCuttoff)
				{
					//Max blend should technicaly be 1, but we make it 0.99 to avoid potential divide by zero errors later
					foamMultiplier = 1 - min(0.99 , (_FoamIntensity * val));
					
					//Blend the the main texture with the foam texture
					c = (foamMultiplier) * c + (1 - foamMultiplier) * foam;
				}
			#endif

			//Set up depth effect variables
			#ifdef DEPTH_FOG
				//Read in depth values
				float rawZ = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos));
				float sceneZ = LinearEyeDepth(rawZ);
				float partZ = IN.color.r;//Use colour sematics to do equivalent of IN.eyeDepth
			
				//Calculate ratio of height difference to depth scaling factor
				float depthRatio = min((sceneZ - partZ)/_depthScale,_maxFog);

				
				if ( rawZ > 0.0 ) // Make sure the depth texture exists
				{
					//Front face Multiplier is a value in the range _maxFade to _maxFog determined by the ratio of height difference to depth scaling factor
					depthMultiplier = max(_maxFade, depthRatio); 

					//Rear face multiplier is similar. but here the max value depends soley on the camera distance to the underside of the water plane.
					depthMultiplierFlip = max(_maxFade, (min((partZ/_depthScale),_maxFog)));
				}
					
			#endif

			//Read in the normal maps
			fixed3 normalSim = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
			fixed3 normalDetail1 = UnpackNormal(tex2D (_NormalDetail, IN.uv_NormalDetail));
			fixed3 normalDetail2 = UnpackNormal(tex2D (_NormalDetail2, IN.uv_NormalDetail2));

			//Set surface paramaters
            o.Albedo = c.rgb;
			o.Metallic = _Metallic * foamMultiplier;
			o.Smoothness = max(0.9,_Smoothness * foamMultiplier);
			o.Normal =  combineNormals(combineNormals(normalSim, normalDetail1), normalDetail2);
			o.Alpha = 1/(foamMultiplier) * c.a; 

			//For front facing verticies, just applu the depth multiplier to alpha channel
			if(IN.facing >= 0.5)
				o.Alpha *=  depthMultiplier;
			//For rear facing verticies, apply the fliped depth multiplier to the alpha channel and flip the normals to make both sides of plane visible.
			else
			{
				o.Alpha *= depthMultiplierFlip;
				o.Normal *= -1.0;
			}		
		}
		ENDCG
	}
	FallBack "Standard"
}
 