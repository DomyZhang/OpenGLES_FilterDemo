precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

uniform float Time;

const float PI = 3.1415926;

void main (void) {
    float duration = 0.6;// 动画时长
    
    float time = mod(Time, duration);// 当前时间 0 ~ 0.6
    
    vec4 whiteMask = vec4(1.0, 1.0, 1.0, 1.0);// 白色图层
    float amplitude = abs(sin(time * (PI / duration)));// 透明度
    // 纹理坐标对应纹素
    vec4 mask = texture2D(Texture, TextureCoordsVarying);
    // mix
    gl_FragColor = mask * (1.0 - amplitude) + whiteMask * amplitude;
}
