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

float torus1(vec3 p, vec2 t){
    vec2 q = vec2(length(p.yz) - t.x, p.x);
    return length(q) - t.y;
}


float torus2(vec3 p, vec2 t){
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float torus3(vec3 p, vec2 t){
    vec2 q = vec2(length(p.xy) - t.x, p.z);
    return length(q) - t.y;
}

float plane(vec3 p, vec4 n){
    return dot(p, n.xyz) + n.w;
}

float blend(float a, float b){
    float k = 0.2;
    float h = clamp(0.5 + 0.5 * (b - a)/k, 0, 1);
    return mix(b, a, h) - k * h * (1-h);
}

float x = 90 * PI / 4;
mat4 rotation = mat4 (
    vec4(cos(x), 0, sin(x), 0),
    vec4(0, 1, 0, 0),
    vec4(-sin(x), 0, cos(x), 0),
    vec4(0, 0, 0, 1));

float fSceneTorus(vec3 p){

    float torus1;
    vec3 p1 = p + vec3(4,0,4);
    p1 = mod(p1, vec3(8,0,8));
    p1 = p1 - vec3(4,0,4);

    torus1 = torus1(p1, vec2(3, 0.5));

    float torus2;
    vec3 p2 = p - vec3(0,0,4);
    p2 = p2 + vec3(4,0,4);
    p2 = mod(p2, vec3(8,0,8));
    p2 = p2 - vec3(4,0,4);

    torus2 = torus2(p2, vec2(3, 0.5));

    float torus3;
    vec3 p3 = p - vec3(4,0,4);
    p3 = p3 + vec3(4,0,4);
    p3 = mod(p3, vec3(8,0,8));
    p3 = p3 - vec3(4,0,4);

    torus3 = torus3(p3, vec2(3, 0.5));

    return min(min(torus3, torus2), torus1);
}

float fPlane(vec3 p){
    return plane(vec3(p) - vec3(0, -1, 0), vec4(0, 1, 0, 0));
}

float softShadow(vec3 p) {

     int i = 0;
     float kd;

    vec3 lightDir = normalize(LIGHT_POS[i] - p);
    kd = 1;
    int step = 0;

    for (float t = 0.1; t < length(LIGHT_POS[i] - p) && step < RENDER_DEPTH && kd > 0.001; ){
        float d = abs(fSceneTorus(p + t * lightDir));
        if (d < 0.001){
            kd = 0;
        } else {
            kd = min(kd, 16 * d/t);
        }

        t += d;
        step++;
        i++;
    }


     return kd;
}

float f(vec3 p){

    float x = fSceneTorus(p);
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
    float x = fSceneTorus(pt);
    float y = fPlane(pt);
    vec3 colour;

    if (x < y){
        colour = getColor(pt);
    } else {
        x = mod(x, 5);

        if (4.75 <= x){
             colour = vec3(0,0,0);
        }

        if (x < 4.75){
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

    float kd = softShadow(pt);
    float diffuse = kd * max(dot(n, l), 0);
    val += diffuse;

    vec3 viewDir = normalize(pt - eye);
    vec3 reflectDir = normalize(reflect(l, normalize(n)));

    float specular = kd * pow(max(dot(reflectDir, viewDir), 0), 256);
    val += specular;

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