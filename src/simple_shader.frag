#version 460

smooth in vec4 the_color;
in vec2 TexCoord;

uniform sampler2D ourTexture;

uniform vec2 offset, scale;
uniform float rot;


out vec4 outputColor;
void main()
{

    mat3 translation = mat3(1,0,0,0,1,0, offset.x, offset.y, 1);
    mat3 rotation = mat3(
	cos(rot), sin(rot), 0,
	-sin(rot), cos(rot), 0,
        0,             0, 1
    );
    mat3 scale = mat3(scale.x,0,0, 0,scale.y,0, 0,0,1);

    mat3 matrix = translation * rotation * scale;
    vec2 uvTransformed = ( matrix * vec3(TexCoord.xy, 1) ).xy;
    outputColor = texture(ourTexture, uvTransformed);
}
