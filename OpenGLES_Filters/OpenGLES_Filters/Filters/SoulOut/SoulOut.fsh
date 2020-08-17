precision highp float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

uniform float Time;

void main (void) {
    float duration = 0.7;// 一次动效时长
    float maxAlpha = 0.4;// 最大透明度
    float maxScale = 1.8;// 缩放最大系数
    
    float progress = mod(Time, duration) / duration;// mod(Time, duration)：0~0.7 --> 0~1
    float alpha = maxAlpha * (1.0 - progress);// 计算透明度
    float scale = 1.0 + (maxScale - 1.0) * progress;// 计算缩放倍数
    
    float weakX = 0.5 + (TextureCoordsVarying.x - 0.5) / scale;// 纹理坐标值缩放
    float weakY = 0.5 + (TextureCoordsVarying.y - 0.5) / scale;
    vec2 weakTextureCoords = vec2(weakX, weakY);// 缩放后纹理坐标
    // 缩放后纹理坐标对应的纹素
    vec4 weakMask = texture2D(Texture, weakTextureCoords);
    // 原纹理坐标对应纹素
    vec4 mask = texture2D(Texture, TextureCoordsVarying);
    // 混合2个图层
    gl_FragColor = mask * (1.0 - alpha) + weakMask * alpha;// mix
}
