#include <metal_stdlib>
using namespace metal;
struct Uniforms { float4 values[32]; };
struct MeshOutput { float4 position [[position]]; float4 color; };
float2 catmull2(float2 a, float2 b, float2 c, float2 d, float t) {
    float t2=t*t, t3=t2*t;
    return 0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t2+(-a+3.0*b-3.0*c+d)*t3);
}
float4 catmull4(float4 a, float4 b, float4 c, float4 d, float t) {
    float t2=t*t, t3=t2*t;
    return 0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t2+(-a+3.0*b-3.0*c+d)*t3);
}
float srgbToLinearChannel(float value) {
    return value<=0.04045 ? value/12.92 : pow((value+0.055)/1.055,2.4);
}
float4 srgbToLinear(float4 color) {
    color=clamp(color,0.0,1.0);
    return float4(srgbToLinearChannel(color.r),srgbToLinearChannel(color.g),srgbToLinearChannel(color.b),color.a);
}
float2 segment(float value) {
    float scaled=clamp(value,0.0,1.0)*3.0;
    float index=min(floor(scaled),2.0);
    return float2(index,scaled-index);
}
int pointIndex(int column,int row) { return row*4+column; }
float2 meshPosition(float2 parameter,constant Uniforms &uniforms) {
    float2 sx=segment(parameter.x), sy=segment(parameter.y);
    int ix=int(sx.x), iy=int(sy.x);
    int x0=max(ix-1,0),x1=ix,x2=ix+1,x3=min(ix+2,3);
    int y0=max(iy-1,0),y1=iy,y2=iy+1,y3=min(iy+2,3);
    float2 row0=catmull2(uniforms.values[pointIndex(x0,y0)].xy,uniforms.values[pointIndex(x1,y0)].xy,uniforms.values[pointIndex(x2,y0)].xy,uniforms.values[pointIndex(x3,y0)].xy,sx.y);
    float2 row1=catmull2(uniforms.values[pointIndex(x0,y1)].xy,uniforms.values[pointIndex(x1,y1)].xy,uniforms.values[pointIndex(x2,y1)].xy,uniforms.values[pointIndex(x3,y1)].xy,sx.y);
    float2 row2=catmull2(uniforms.values[pointIndex(x0,y2)].xy,uniforms.values[pointIndex(x1,y2)].xy,uniforms.values[pointIndex(x2,y2)].xy,uniforms.values[pointIndex(x3,y2)].xy,sx.y);
    float2 row3=catmull2(uniforms.values[pointIndex(x0,y3)].xy,uniforms.values[pointIndex(x1,y3)].xy,uniforms.values[pointIndex(x2,y3)].xy,uniforms.values[pointIndex(x3,y3)].xy,sx.y);
    return catmull2(row0,row1,row2,row3,sy.y);
}
float4 meshColor(float2 parameter,constant Uniforms &uniforms) {
    float2 sx=segment(parameter.x),sy=segment(parameter.y);
    int ix=int(sx.x),iy=int(sy.x);
    int x0=max(ix-1,0),x1=ix,x2=ix+1,x3=min(ix+2,3);
    int y0=max(iy-1,0),y1=iy,y2=iy+1,y3=min(iy+2,3);
    int offset=16;
    float4 row0=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y0)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y0)]),sx.y);
    float4 row1=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y1)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y1)]),sx.y);
    float4 row2=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y2)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y2)]),sx.y);
    float4 row3=catmull4(srgbToLinear(uniforms.values[offset+pointIndex(x0,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x1,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x2,y3)]),srgbToLinear(uniforms.values[offset+pointIndex(x3,y3)]),sx.y);
    return clamp(catmull4(row0,row1,row2,row3,sy.y),0.0,1.0);
}
vertex MeshOutput meshVertex(uint id [[vertex_id]],device const float2 *parameters [[buffer(0)]],constant Uniforms &uniforms [[buffer(1)]]) {
    float2 position=meshPosition(parameters[id],uniforms);
    MeshOutput output;
    // Cache the complete shader node; the final pass applies its original crop.
    output.position=float4(position.x*2.0-1.0,1.0-position.y*2.0,0.0,1.0);
    output.color=meshColor(parameters[id],uniforms);
    return output;
}
fragment float4 meshFragment(MeshOutput input [[stage_in]]) { return input.color; }
struct ResolveOutput { float4 position [[position]]; };
vertex ResolveOutput resolveVertex(uint id [[vertex_id]]) {
    const float2 points[6]={float2(-1,-1),float2(1,-1),float2(-1,1),float2(-1,1),float2(1,-1),float2(1,1)};
    ResolveOutput output; output.position=float4(points[id],0,1); return output;
}
float linearToSrgbChannel(float value) {
    float safeValue=max(value,0.0);
    return safeValue<=0.0031308 ? safeValue*12.92 : 1.055*pow(safeValue,1.0/2.4)-0.055;
}
float grain(uint2 pixel,uint seed) {
    // Integer avalanche hash: physical pixel coordinates, no time or tilt input.
    uint value=pixel.x*1973u+pixel.y*9277u+seed*26699u;
    value=(value^(value>>16u))*0x7feb352du;
    value=(value^(value>>15u))*0x846ca68bu;
    value=value^(value>>16u);
    return float(value)*(1.0/4294967295.0)*2.0-1.0;
}
fragment float4 resolveFragment(ResolveOutput input [[stage_in]],texture2d<float> source [[texture(0)]],constant float4 &effects [[buffer(0)]],constant float4 &dimensions [[buffer(1)]]) {
    uint2 pixel=uint2(input.position.xy);
    float2 screenUV=input.position.xy/dimensions.xy;
    float2 meshUV=(screenUV-effects.xy-0.5)*float2(402.0/449.695,874.0/977.696)+0.5;
    meshUV.x-=0.04/449.695;
    constexpr sampler linearSampler(coord::normalized,address::clamp_to_edge,filter::linear);
    float4 color=source.sample(linearSampler,meshUV);
    float3 rgb=clamp(float3(linearToSrgbChannel(color.r),linearToSrgbChannel(color.g),linearToSrgbChannel(color.b)),0.0,1.0);
    // Figma's white Color blend keeps backdrop luminosity, then white Screen at 30%.
    float luminosity=dot(rgb,float3(0.30,0.59,0.11));
    float baseGray=luminosity*0.70+0.30;
    float grainStrength=1.0;
    if (dimensions.z>1.5) { baseGray=0.79+luminosity*0.35; grainStrength=0.70; }
    else if (dimensions.z>0.5) { baseGray=0.07+luminosity*0.42; grainStrength=0.55; }
    float finalGray=clamp(baseGray+grain(pixel,uint(effects.w))*effects.z*grainStrength,0.0,1.0);
    return float4(finalGray,finalGray,finalGray,color.a);
}
