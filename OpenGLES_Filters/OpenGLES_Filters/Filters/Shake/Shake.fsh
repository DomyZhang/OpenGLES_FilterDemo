precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

uniform float Time;

void main (void) {
    float duration = 0.7;
    float maxScale = 1.1;
    float offset = 0.02;
    
    float progress = mod(Time, duration) / duration; // 0~1
    vec2 offsetCoords = vec2(offset, offset) * progress;// 偏移量
    float scale = 1.0 + (maxScale - 1.0) * progress;// 缩放
    
    vec2 ScaleTextureCoords = vec2(0.5, 0.5) + (TextureCoordsVarying - vec2(0.5, 0.5)) / scale;// 纹理坐标缩放 - 向量的加减 例：向量 AB, A+B=(Ax+Bx, Ay+By)
    
    vec4 maskR = texture2D(Texture, ScaleTextureCoords + offsetCoords);// red
    vec4 maskB = texture2D(Texture, ScaleTextureCoords - offsetCoords);// blue
    vec4 mask = texture2D(Texture, ScaleTextureCoords);// 原纹素
    
    gl_FragColor = vec4(maskR.r, mask.g, maskB.b, mask.a);// RGB 中 RB 取b偏移后的值
}

