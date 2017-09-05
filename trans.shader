﻿Shader "Custom/Transparent"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalMap ("Simulation Normal Map", 2D) = "bump" {}
		_NormalDetail ("Normal Detail Map", 2D) = "bump" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

		
        _Tess ("Tessellation", Range(1,162)) = 4
        _Displacement ("Displacement", Range(-10.0, 10.0)) = 0.3
    }
    SubShader
    {
	 Cull Off
        Tags {"Queue" = "Transparent" "RenderType"="Transparent" }
        LOD 300
   
        CGPROGRAM
 
		//Edge Based
		// #pragma surface surf Standard fullforwardshadows alpha:fade vertex:disp tessellate:tessEdge
		
		//Distance Based
		#pragma surface surf Standard fullforwardshadows alpha:fade vertex:disp tessellate:tessDistance

        #pragma target 5.0
        #include "Tessellation.cginc"
 
		struct appdata {
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
		
		//Distance based	
	    float _Tess;
		
	    float4 tessDistance (appdata v0, appdata v1, appdata v2) 
		{
			float minDist = .25;
			float maxDist = 15.0;
                return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _Tess);
        }


	   //Edge Based
	   // float _EdgeLength;

		//float4 tessEdge (appdata v0, appdata v1, appdata v2)
		//{
		 //   return UnityEdgeLengthBasedTess (v0.vertex, v1.vertex, v2.vertex, _EdgeLength);
		//}
           
		float _Displacement;
 
		void disp (inout appdata v)
		{
			float d = ((tex2Dlod( _NormalMap , float4(v.texcoord.xy ,0,0)).a - 0.5)) * _Displacement;
			v.vertex.xyz += v.normal * d;
		}

 
        struct Input {
            float2 uv_MainTex;
			float2 uv_NormalMap;
			float2 uv_NormalDetail;
        };
 

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
 
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;			
			o.Normal =UnpackNormal (tex2D(_NormalMap, IN.uv_NormalMap) + tex2D (_NormalDetail, IN.uv_NormalDetail)*2-1);
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Standard"
}
 