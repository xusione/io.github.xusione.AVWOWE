#!/bin/bash
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export GLFW_PLATFORM=x11

exec /app/bin/AVWOWE "$@"