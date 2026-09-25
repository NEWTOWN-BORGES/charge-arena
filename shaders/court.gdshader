shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform vec4 sector_tint : source_color = vec4(0.15, 0.27, 0.30, 1.0);
uniform float finish_quality = 2.0;
uniform sampler2D surface_grain : filter_linear_mipmap_anisotropic, repeat_enable;
void vertex(){world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
float ring_line(float r,float target,float width){float aa=max(fwidth(r),0.008);return 1.0-smoothstep(max(0.0,width-aa),width+aa,abs(r-target));}
void fragment(){
 vec2 p=world_pos.xz;
 vec2 tile=floor((p+vec2(0.9))/1.8);
 vec2 cell=abs(fract(p/1.8+0.5)-0.5);
 float edge=max(cell.x,cell.y);
 float aa=max(fwidth(edge),0.001);
 float seam=smoothstep(0.483-aa,0.499,edge);
 float bevel=smoothstep(0.458,0.475,edge)*(1.0-seam);
 vec3 team=p.y>0.0?vec3(0.08,0.92,0.74):vec3(1.0,0.24,0.16);
 vec3 base=mix(vec3(0.048,0.086,0.13),sector_tint.rgb*0.62,0.62);
 base*=1.0+0.06*mod(tile.x+tile.y,2.0);
 base=mix(base,vec3(0.018,0.038,0.057),seam*0.82);
 base+=vec3(0.035,0.055,0.068)*bevel;
 float grain=finish_quality>0.5?texture(surface_grain,p*0.75).r:0.94;
 base*=0.93+grain*0.12;
 float r=length(p);
 float center=ring_line(r,2.12,0.018)+ring_line(r,2.28,0.009);
 float medallion=ring_line(r,1.86,0.008);
 // On Refinado the dial turns slowly, like a machine that is switched on.
 float turn=finish_quality>1.5?TIME*0.08:0.0;
 float ticks=step(0.80,fract((atan(p.y,p.x)+turn)*20.0/6.28318));
 float dial=ring_line(r,2.43,0.065)*ticks;
 base=mix(base,vec3(0.35,0.55,0.57),clamp(center+dial*0.6,0.0,1.0)*0.6);
 base=mix(base,vec3(0.61,0.44,0.19),medallion*0.7);
 float mid=1.0-smoothstep(0.009,0.009+fwidth(p.y),abs(p.y));
 float dash=step(0.5,fract(p.x*1.5));
 base=mix(base,vec3(0.48,0.65,0.65),mid*dash*0.45);
 float wash=pow(smoothstep(3.0,9.0,abs(p.y)),2.0);
 ALBEDO=base;
 METALLIC=0.28;
 bool showcase=finish_quality>1.5;
 // Refinado polishes the plates, so the flashes of shots and blasts run across the floor.
 ROUGHNESS=showcase?mix(0.3,0.7,seam):mix(0.54,0.74,seam);
 SPECULAR=0.65;
 CLEARCOAT=showcase?0.55:0.0;
 CLEARCOAT_ROUGHNESS=showcase?0.14:0.4;
 vec3 glow=team*wash*0.038+vec3(0.13,0.25,0.23)*center*0.10;
 if(showcase){
  // Energy in the seams, each half in its own team's colour, pulsing outward from the
  // centre line towards the walls: the arena looks powered.
  float half_dist=abs(p.y);
  float pulse=pow(0.5+0.5*sin(half_dist*1.35-TIME*2.6),8.0);
  float live=seam*(0.06+0.94*pulse)*smoothstep(0.6,2.2,half_dist);
  glow+=team*live*1.25;
  glow+=vec3(0.35,0.75,0.8)*(center+dial*0.5)*(0.35+0.25*sin(TIME*1.7));
 }
 EMISSION=glow;
}
