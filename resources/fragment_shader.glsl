#version 330

uniform vec2 resolution;
uniform float currentTime;
uniform vec3 camPos;
uniform vec3 camDir;
uniform vec3 camUp;
uniform sampler2D tex;
uniform bool showStepDepth;

in vec3 pos;

out vec3 color;

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 800
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

#define GRADIENT(pt, func) vec3( \
    func(vec3(pt.x + 0.0001, pt.y, pt.z)) - func(vec3(pt.x - 0.0001, pt.y, pt.z)), \
    func(vec3(pt.x, pt.y + 0.0001, pt.z)) - func(vec3(pt.x, pt.y - 0.0001, pt.z)), \
    func(vec3(pt.x, pt.y, pt.z + 0.0001)) - func(vec3(pt.x, pt.y, pt.z - 0.0001)))

const vec3 LIGHT_POS[] = vec3[](vec3(5, 18, 10));

///////////////////////////////////////////////////////////////////////////////

vec3 getBackground(vec3 dir) {
  float u = 0.5 + atan(dir.z, -dir.x) / (2 * PI);
  float v = 0.5 - asin(dir.y) / PI;
  vec4 texColor = texture(tex, vec2(u, v));
  return texColor.rgb;
}

vec3 getRayDir() {
  vec3 xAxis = normalize(cross(camDir, camUp));
  return normalize(pos.x * (resolution.x / resolution.y) * xAxis + pos.y * camUp + 5 * camDir);
}

///////////////////////////////////////////////////////////////////////////////

float sphere(vec3 pt) {
  return length(pt) - 1;
}

/**
float cube(vec3 p) {
  vec3 d = abs(p);
  return max(d.x, max(d.y, d.z)) - 1;
}
*/

float cube(vec3 p) {
    vec3 d = abs(p) - vec3(1); // 1 = radius
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float plane(vec3 p, vec4 n){
    return dot(p, n.xyz) + n.w;
}

float blend(float a, float b){
    float k = 0.2;
    float h = clamp(0.5 + 0.5 * (b - a)/k, 0, 1);
    return mix(b, a, h) - k * h * (1-h);
}

//returns closest jump that can be taken from sdf of scene and its objects
float fScene(vec3 p){

    float cube1, cube2, cube3, cube4;
    float sphere1, sphere2, sphere3, sphere4;
    float shape1, shape2, shape3, shape4;

    cube1 = cube(p - vec3(-3,0,-3));
    sphere1 = sphere(p - vec3(-2, 0, -2));
    shape1 = min(cube1, sphere1);

    cube2 = cube(p - vec3(3,0,-3));
    sphere2 = sphere(p - vec3(4, 0, -2));
    shape2 = max(cube2, -sphere2);

    cube3 = cube(p - vec3(-3,0,3));
    sphere3 = sphere(p - vec3(-2,0,4));
    shape3 = blend(cube3, sphere3);

    cube4 = cube(p - vec3(3,0,3));
    sphere4 = sphere(p - vec3(4,0,4));
    shape4 = max(cube4, sphere4);

    float unioned = min(min(shape1 , shape2), min(shape3, shape4));

    return unioned;
}

float fPlane(vec3 p){
    return plane(vec3(p) - vec3(0, -1, 0), vec4(0, 1, 0, 0));
}

float f(vec3 p){
    float x = fScene(p);
    float y = fPlane(p);

    return min(x,y);
}


vec3 getNormal(vec3 pt) {
  return normalize(GRADIENT(pt, f));
}

vec3 getColor(vec3 pt) {
  return vec3(1);
}

//need colour based on sd of pt from the cubes
vec3 getDistanceColour(vec3 pt){
    float x = fScene(pt);
    float y = fPlane(pt);
    vec3 colour;

    if (x < y){
        colour = getColor(pt);
    } else {
        x = mod(x, 5.25);

        if (5 <= x){
             colour = vec3(0,0,0);
        }

        if (x < 5){
            float x2 = mod(x, 1);
            colour = mix(vec3(0.4, 1,  0.4), vec3(0.4, 0.4, 1), x2);
        }
    }

    return colour;
}


///////////////////////////////////////////////////////////////////////////////

float shade(vec3 eye, vec3 pt, vec3 n) {
  float val = 0;
  
  val += 0.1;  // Ambient
  
  for (int i = 0; i < LIGHT_POS.length(); i++) {
    vec3 l = normalize(LIGHT_POS[i] - pt); 
    val += max(dot(n, l), 0);
  }
  return val;
}

vec3 illuminate(vec3 camPos, vec3 rayDir, vec3 pt) {
  vec3 c, n;
  n = getNormal(pt);
  c = getDistanceColour(pt);
  return shade(camPos, pt, n) * c;
}

///////////////////////////////////////////////////////////////////////////////

vec3 raymarch(vec3 camPos, vec3 rayDir) {
  int step = 0;
  float t = 0;

  for (float d = 1000; step < RENDER_DEPTH && abs(d) > CLOSE_ENOUGH; t += abs(d)) {

 //    d = sphere(camPos + t * rayDir);

//    d = cube(camPos + t * rayDir);

      d = f(camPos + t * rayDir);

//changing camPos moves the origin of the camera itself

    step++;
  }

  if (step == RENDER_DEPTH) {
    return getBackground(rayDir);
  } else if (showStepDepth) {
    return vec3(float(step) / RENDER_DEPTH);
  } else {
    return illuminate(camPos, rayDir, camPos + t * rayDir);
  }
}

///////////////////////////////////////////////////////////////////////////////

void main() {
  color = raymarch(camPos, getRayDir());
}