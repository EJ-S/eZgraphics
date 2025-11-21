#version 460

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normals;
layout(location = 3) in vec2 texcoord_0;
layout(location = 5) in vec4 color_0;
layout(location = 6) in vec4 color_1;

uniform mat4 perspective_matrix;
uniform mat4 trs_matrix;
uniform mat4 world_to_camera;
uniform vec4 color;

smooth out vec4 the_color;

void main()
{
    //vec4 tmp = vec4(position.xy * 0.25, position.z * .75 - 2.0, 1.0);
    //vec4 camera_pos = tmp + vec4(0.5, 0.5, 0.0, 0.0);
    //gl_Position = perspective_matrix * camera_pos;
    vec4 world_pos = trs_matrix * vec4(position, 1.0);
    vec4 camera_pos = world_to_camera * world_pos;
    gl_Position = perspective_matrix * camera_pos;
    the_color = color;
}
