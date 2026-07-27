#!/bin/bash
export LD_LIBRARY_PATH="/app/lib:/app/lib64:${LD_LIBRARY_PATH}"
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export GLFW_PLATFORM=x11

exec /app/bin/AVWOWE "$@"
