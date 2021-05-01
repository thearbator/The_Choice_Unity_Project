﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/ToonShader_Outlined"
{
	// Variables
	Properties
	{
		// TEXTURE
		// Allows for a texture property
		[Header(Textures)]
		_MainTex("Main Texture (RGB)", 2D) = "white" {}
		_Color("Main Color", Color) = (.5,.5,.5,1)

		// OUTLINE
		[Header(Outline Settings)]
		_OutlineTex("Outline texture", 2D) = "white" {}
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_OutlineWidth("Outline Width", Range(0.0, 5.0)) = 0.2
		_OutlineWidthFill("Outline Width Fill Amount", float) = 1.0

		// COLOURING		
		[Header(Coloruing Effect Settings)]
		_EffectColor("Effect color", color) = (1, 1, 1, 1)
		[HideInInspector]
		_EffectDistance("Effect distance", float) = 10.0
		_EffectStrokeColor("Effect stroke color", color) = (0, 0, 0, 1)
		_EffectRadius("Effect stroke weight", float) = 0.1
		_EffectScale("Effect scale", float) = 0.1
		_EffectSpeed("Effect speed", float) = 1.0
		_EffectFrequency("Effect frequency", float) = 1.0
	}

	SubShader
	{
		Tags
		{
			"Queue" = "Transparent+2"
		}
		Lighting Off

		// Outline
		Pass
		{
			Name "OUTLINE"

			ZWrite Off
			Cull Front
			//ZTest LEqual

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			sampler2D _OutlineTex;
			float4 _OutlineTex_ST;

			fixed4 _OutlineColor;
			fixed _OutlineWidth;
			fixed _OutlineWidthFill;

			v2f vert(appdata IN)
			{
				IN.vertex.xyz += IN.color * (_OutlineWidth * _OutlineWidthFill);
				
				v2f OUT;

				OUT.pos = UnityObjectToClipPos(IN.vertex);
				OUT.uv = TRANSFORM_TEX(IN.uv, _OutlineTex); // Tiling

				return OUT;
			}

			fixed4 frag(v2f IN) : SV_TARGET
			{
				float4 texColor = tex2D(_OutlineTex, IN.uv);
				return texColor * _OutlineColor;
			}

			ENDCG
		}
	
		// Coloured and lit pass
		Tags
		{
			"RenderType" = "Opaque"
			"Queue" = "Geometry"
		}
		Lighting On
		Pass
		{
			Tags { "LightMode" = "ForwardBase" }

			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			// compile shader into multiple variants, with and without shadows
			// (we don't care about any lightmaps yet, so skip these variants)
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
			// shadow helper functions and macros
			#include "AutoLight.cginc"

			struct v2f
			{
				float4 pos				: SV_POSITION;
				float2 texcoord			: TEXCOORD0;
				float3 normal			: TEXCOORD1;
				float3 lightDir			: TEXCOORD2;
				LIGHTING_COORDS(3, 4)
				float3 worldPosOffset	: TEXCOORD5;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			fixed4 _Color;


			fixed _ArraySize;
			fixed4 _Positions[1000];
			fixed _Distances[1000];


			fixed4 _EffectColor;
			fixed _EffectDistance;
			fixed4 _EffectStrokeColor;
			fixed _EffectRadius;
			fixed _EffectScale;
			fixed _EffectSpeed;
			fixed _EffectFrequency;

			v2f vert(appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex); // Tiling

				// Lighting 
				o.lightDir = ObjSpaceLightDir(v.vertex);
				o.normal = v.normal;

				// Moving world pos for colouring circle ripple effect
				o.worldPosOffset = mul(unity_ObjectToWorld, v.vertex);

				float3 tempV = o.worldPosOffset;
				
				o.worldPosOffset.x += _EffectScale * sin(_Time.w * _EffectSpeed + ((tempV.z + tempV.y) * 0.5) * _EffectFrequency);
				o.worldPosOffset.z += _EffectScale * sin(_Time.w * _EffectSpeed + ((tempV.x + tempV.y) * 0.5) * _EffectFrequency);

				return o;
			}

			fixed4 frag(v2f a_i) : SV_Target
			{
				a_i.lightDir = normalize(a_i.lightDir);

				fixed4 col = tex2D(_MainTex, a_i.texcoord);
				col *= _Color;
				fixed4 output = col;

				// Compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
				fixed atten = LIGHT_ATTENUATION(a_i);

				// The following code is really janky but it works and
				// its decently efficient considering what I'd have to do
				// to make it not janky so I'm leaving it like this

				// Finding the lowest distance to the nearest position
				// This starts as a really high numbers so that it is guaranteed there
				// is a position in range of this number
				float mag = 10000;
				for (int i = 0; i < _ArraySize; ++i)
				{
					float dist = distance(_Positions[i].xyz, a_i.worldPosOffset);
					float offsetDist = dist - _Distances[i] + 10;

					mag = clamp(offsetDist, 0, mag);
				}

				float distanceTwo = _EffectDistance + -_EffectRadius;

				fixed4 borderColor = output - _EffectStrokeColor;

				fixed4 outputColour = output + (mul(step(_EffectDistance, mag), _EffectColor)) - (mul(step(distanceTwo, mag), borderColor));
				
				
				fixed diff = saturate(dot(a_i.normal, a_i.lightDir));

				fixed4 c;
				c.rgb = (outputColour * _LightColor0.rgb * diff) * (atten * 2);
				c.a = outputColour.a;

				// Return the colour
				return c;
			}
			ENDCG
		}

		// Blending in other light sources such as point lights
		Pass
		{
			Tags{ "LightMode" = "ForwardAdd" }                       // Again, this pass tag is important otherwise Unity may not give the correct light information.
			Blend One One                                         // Additively blend this pass with the previous one(s). This pass gets run once per pixel light.

			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd                        // This line tells Unity to compile this pass for forward add, giving attenuation information for the light.
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float2 texcoord	: TEXCOORD0;
				float3 normal	: TEXCOORD1;
				float3 lightDir	: TEXCOORD2;
				LIGHTING_COORDS(3,4)                            // Macro to send shadow & attenuation to the vertex shader.

				float3 worldPosOffset	: TEXCOORD5;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			fixed4 _Color;


			fixed _ArraySize;
			fixed4 _Positions[1000];
			fixed _Distances[1000];


			fixed4 _EffectColor;
			fixed _EffectDistance;
			fixed4 _EffectStrokeColor;
			fixed _EffectRadius;
			fixed _EffectScale;
			fixed _EffectSpeed;
			fixed _EffectFrequency;

			v2f vert(appdata_full v)
			{
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);

				// Tiling
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);

				o.lightDir = ObjSpaceLightDir(v.vertex);
				o.normal = v.normal;

				// Moving world pos for colouring circle ripple effect
				o.worldPosOffset = mul(unity_ObjectToWorld, v.vertex);

				float3 tempV = o.worldPosOffset;

				o.worldPosOffset.x += _EffectScale * sin(_Time.w * _EffectSpeed + ((tempV.z + tempV.y) * 0.5) * _EffectFrequency);
				o.worldPosOffset.z += _EffectScale * sin(_Time.w * _EffectSpeed + ((tempV.x + tempV.y) * 0.5) * _EffectFrequency);

				TRANSFER_VERTEX_TO_FRAGMENT(o);                 // Macro to send shadow & attenuation to the fragment shader.
				return o;
			}

			fixed4 _LightColor0; // Colour of the light used in this pass.

			fixed4 frag(v2f a_i) : COLOR
			{
				a_i.lightDir = normalize(a_i.lightDir);

				fixed4 col = tex2D(_MainTex, a_i.texcoord);
				col *= _Color;
				fixed4 output = col;

				// Compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
				fixed atten = LIGHT_ATTENUATION(a_i);

				// The following code is really janky but it works and
				// its decently efficient considering what I'd have to do
				// to make it not janky so I'm leaving it like this

				// Finding the lowest distance to the nearest position
				// This starts as a really high numbers so that it is guaranteed there
				// is a position in range of this number
				float mag = 10000;
				for (int i = 0; i < _ArraySize; ++i)
				{
					float dist = distance(_Positions[i].xyz, a_i.worldPosOffset);
					float offsetDist = dist - _Distances[i] + 10;

					mag = clamp(offsetDist, 0, mag);
				}

				float distanceTwo = _EffectDistance + -_EffectRadius;
				fixed4 borderColor = output - _EffectStrokeColor;

				fixed4 outputColour = output + (mul(step(_EffectDistance, mag), _EffectColor)) - (mul(step(distanceTwo, mag), borderColor));


				fixed diff = saturate(dot(a_i.normal, a_i.lightDir));

				fixed4 c;
				c.rgb = (outputColour * _LightColor0.rgb * diff) * (atten * 2);
				c.a = outputColour.a;

				// Return the colour
				return c;
			}
			ENDCG
		}

		// pull in shadow caster from VertexLit built-in shader
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}

	Fallback "VertexLit"
}


