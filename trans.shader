Shader "RealWater/PBR_Refractive_Tesselation"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalMap ("Simulation Normal Map", 2D) = "bump" {}
		_NormalDetail ("Normal Detail Map", 2D) = "bump" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

		_BumpAmt  ("Distortion", range (0,256)) = 10
        _Tess ("Tessellation", Range(1,162)) = 4
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
				Name "Tessel"
				Tags { "LightMode" = "Always" }
				
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

float _BumpAmt;
float4 _BumpMap_ST;
float4 _NormalDetail_ST;
float4 _MainTex_ST;

v2f vert (appdata_t v)
{
	v2f o;
	o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
	#if UNITY_UV_STARTS_AT_TOP
	float scale = -1.0;
	#else
	float scale = 1.0;
	#endif
	o.uvgrab.xy = (float2(o.vertex.x, o.vertex.y*scale) + o.vertex.w) * 0.5;
	o.uvgrab.zw = o.vertex.zw;
	o.uvbump = (TRANSFORM_TEX(v.texcoord, _NormalDetail));// +(TRANSFORM_TEX(v.texcoord, _NormalDetail));
	o.uvmain = TRANSFORM_TEX( v.texcoord, _MainTex );
	UNITY_TRANSFER_FOG(o,o.vertex);
	return o;
}

sampler2D _GrabTexture;
float4 _GrabTexture_TexelSize;
sampler2D _NormalMap;
sampler2D _NormalDetail;
sampler2D _MainTex;
float2 none = (0, 0);

half4 frag (v2f i) : SV_Target
{
	// calculate perturbed coordinates
	half2 bump = UnpackNormal(tex2D( _NormalMap, i.uvmain)).rg; // we could optimize this by just reading the x & y without reconstructing the Z
	half2 bump2 = UnpackNormal(tex2D(_NormalDetail, i.uvbump)).rg; // we could optimize this by just reading the x & y without reconstructing the Z
	half2 bumpCom  = (bump + bump2) * 0.5;
	float2 offset = bumpCom * _BumpAmt * _GrabTexture_TexelSize.xy;
	i.uvgrab.xy = offset * i.uvgrab.z + i.uvgrab.xy;
	
	half4 col = tex2Dproj( _GrabTexture, UNITY_PROJ_COORD(i.uvgrab));
	half4 tint = tex2D(_MainTex, i.uvmain);
	col *= tint;
	UNITY_APPLY_FOG(i.fogCoord, col);
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
				 fixed facing : VFACE;
			};
	 
			
			half _Glossiness;
			half _Metallic;
			fixed4 _Color;
			
			void surf (Input IN, inout SurfaceOutputStandard o)
			{
				fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
				o.Albedo = c.rgb;			
				o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap) + tex2D (_NormalDetail, IN.uv_NormalDetail)*2-1);
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;
				o.Alpha = c.a;
				
				
			}
			ENDCG
		}
		FallBack "Standard"
	}
}
 