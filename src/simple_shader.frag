#version 460

smooth in vec4 the_color;

out vec4 outputColor;
void main()
{
    outputColor = the_color;
}
