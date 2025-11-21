const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const Errors = error{ GlfwWinodwCreationFailed, GlfwInitFailed };

/// Creates a window and sets it to be the current context, if window creation fails glfw will be terminated
pub fn createWindowAndSetContext(glfw_context_version_major: c_int, glfw_context_version_minor: c_int, width: c_int, height: c_int, window_title: []const u8, monitor: ?*c.GLFWmonitor, share_window_context: ?*c.GLFWwindow) !?*c.GLFWwindow {
    if (c.glfwInit() != c.GLFW_TRUE) {
        return Errors.GlfwInitFailed;
    }
    errdefer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, glfw_context_version_major);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, glfw_context_version_minor);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_DEPTH_BITS, 24);
    const window = c.glfwCreateWindow(width, height, @ptrCast(window_title), monitor, share_window_context);
    if (window == null) {
        return Errors.GlfwWinodwCreationFailed;
    }

    //FPS Mouse Motion
    c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    if (c.glfwRawMouseMotionSupported() == c.GLFW_TRUE) c.glfwSetInputMode(window, c.GLFW_RAW_MOUSE_MOTION, c.GLFW_TRUE);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);
    return window;
}

pub const C = c;
