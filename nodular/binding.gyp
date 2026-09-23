{
  "targets": [{
    "target_name": "x11wm",
    "sources": ["src/native/x11wm.cpp"],
    "defines": ["NAPI_VERSION=8"],
    "cflags_cc": ["-std=c++17", "-Wall", "-Wextra", "-pedantic"],
    "cflags_cc!": ["-fno-exceptions"],
    "libraries": ["-lX11"]
  }]
}
