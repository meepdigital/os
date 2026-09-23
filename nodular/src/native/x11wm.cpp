#include <node_api.h>
#include <cstdlib>
#include <sys/stat.h>
#include <X11/XKBlib.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>

#include <algorithm>
#include <cerrno>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {

Display *display = nullptr;
Window root_window = 0;
int screen_width = 0;
int screen_height = 0;
int panel_height = 38;
int socket_fd = -1;
std::string socket_path;
volatile sig_atomic_t running = 1;
void stop_manager(int) { running = 0; }
std::vector<Window> managed_windows;
std::vector<Window> dock_windows;

bool another_window_manager = false;
int x_error_handler(Display *, XErrorEvent *event) {
    if (event->error_code == BadAccess) {
        another_window_manager = true;
    }
    return 0;
}

void send_text(int fd, const std::string &text) {
    const std::string response = text + "\n";
    std::size_t sent = 0;
    while (sent < response.size()) {
        const ssize_t written = write(fd, response.data() + sent, response.size() - sent);
        if (written <= 0) break;
        sent += static_cast<std::size_t>(written);
    }
}

void arrange() {
    managed_windows.erase(
        std::remove_if(managed_windows.begin(), managed_windows.end(), [](Window window) {
            XWindowAttributes attributes{};
            return XGetWindowAttributes(display, window, &attributes) == 0;
        }),
        managed_windows.end());

    if (managed_windows.empty()) {
        for (const Window dock : dock_windows) {
            XRaiseWindow(display, dock);
        }
        XFlush(display);
        return;
    }

    const int usable_height = std::max(1, screen_height - panel_height);
    const int window_height = std::max(1, usable_height / static_cast<int>(managed_windows.size()));
    for (std::size_t index = 0; index < managed_windows.size(); ++index) {
        const int y = static_cast<int>(index) * window_height;
        const int height = index + 1 == managed_windows.size()
            ? usable_height - y
            : window_height;
        XMoveResizeWindow(display, managed_windows[index], 0, y, screen_width, height);
        XMapWindow(display, managed_windows[index]);
    }
    for (const Window dock : dock_windows) {
        XRaiseWindow(display, dock);
    }
    XFlush(display);
}

bool is_dock(Window window) {
    const Atom type_atom = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
    const Atom dock_atom = XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", False);
    Atom actual_type = None;
    int format = 0;
    unsigned long item_count = 0;
    unsigned long bytes_after = 0;
    unsigned char *data = nullptr;
    const int status = XGetWindowProperty(display, window, type_atom, 0, 8, False, XA_ATOM,
                                          &actual_type, &format, &item_count, &bytes_after, &data);
    bool dock = false;
    if (status == Success && data != nullptr) {
        const auto *types = reinterpret_cast<const Atom *>(data);
        for (unsigned long index = 0; index < item_count; ++index) {
            if (types[index] == dock_atom) dock = true;
        }
    }
    if (data != nullptr) XFree(data);
    return dock;
}

void add_window(Window window) {
    if (std::find(managed_windows.begin(), managed_windows.end(), window) == managed_windows.end()) {
        managed_windows.push_back(window);
        arrange();
    }
}

void remove_window(Window window) {
    managed_windows.erase(
        std::remove(managed_windows.begin(), managed_windows.end(), window),
        managed_windows.end());
    dock_windows.erase(std::remove(dock_windows.begin(), dock_windows.end(), window), dock_windows.end());
    arrange();
}

Window focused_window() {
    Window focused = None;
    int revert = RevertToPointerRoot;
    XGetInputFocus(display, &focused, &revert);
    if (std::find(managed_windows.begin(), managed_windows.end(), focused) != managed_windows.end()) {
        return focused;
    }
    return managed_windows.empty() ? None : managed_windows.back();
}

void launch_terminal() {
    const pid_t pid = fork();
    if (pid == 0) {
        close(ConnectionNumber(display));
        // A D-Bus activated host terminal may reuse the host display. xterm
        // opens a fresh X connection on the nested DISPLAY directly.
        if (std::getenv("NODULAR_NESTED"))
            execlp("xterm", "xterm", static_cast<char *>(nullptr));
        execlp("x-terminal-emulator", "x-terminal-emulator", static_cast<char *>(nullptr));
        execlp("xterm", "xterm", static_cast<char *>(nullptr));
        _exit(127);
    }
}

void handle_command(int client_fd, const std::string &command) {
    if (command == "ping") {
        send_text(client_fd, "pong");
    } else if (command == "windows") {
        std::ostringstream result;
        for (std::size_t index = 0; index < managed_windows.size(); ++index) {
            if (index != 0) result << ' ';
            result << managed_windows[index];
        }
        send_text(client_fd, result.str());
    } else if (command.rfind("focus ", 0) == 0) {
        const Window window = static_cast<Window>(std::stoul(command.substr(6)));
        if (std::find(managed_windows.begin(), managed_windows.end(), window) != managed_windows.end()) {
            XSetInputFocus(display, window, RevertToPointerRoot, CurrentTime);
            XRaiseWindow(display, window);
            XFlush(display);
            send_text(client_fd, "ok");
        } else {
            send_text(client_fd, "unknown-window");
        }
    } else if (command == "close") {
        const Window window = focused_window();
        if (window != None) XKillClient(display, window);
        send_text(client_fd, "ok");
    } else if (command == "launch-terminal") {
        launch_terminal();
        send_text(client_fd, "ok");
    } else if (command == "quit") {
        send_text(client_fd, "ok");
        std::raise(SIGTERM);
    } else {
        send_text(client_fd, "unknown-command");
    }
}

void create_socket() {
    if (socket_path.empty() || socket_path.size() >= sizeof(sockaddr_un::sun_path))
        throw std::runtime_error("NODULAR_WM_SOCKET must be a private Unix socket path");
    socket_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (socket_fd < 0) throw std::runtime_error("cannot create Nodular socket");
    sockaddr_un address{};
    address.sun_family = AF_UNIX;
    std::strncpy(address.sun_path, socket_path.c_str(), sizeof(address.sun_path) - 1);
    if (bind(socket_fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) < 0 || listen(socket_fd, 8) < 0) {
        throw std::runtime_error("cannot bind Nodular socket");
    }
}

void set_wm_name() {
    const Atom name_atom = XInternAtom(display, "_NET_WM_NAME", False);
    const Atom utf8_atom = XInternAtom(display, "UTF8_STRING", False);
    const char name[] = "Nodular";
    XChangeProperty(display, root_window, name_atom, utf8_atom, 8, PropModeReplace,
                    reinterpret_cast<const unsigned char *>(name), sizeof(name) - 1);
}

} // namespace

int run_manager() {
    const char *configured_socket = std::getenv("NODULAR_WM_SOCKET");
    if (!configured_socket) throw std::runtime_error("NODULAR_WM_SOCKET is required");
    socket_path = configured_socket;
    running = 1;
    another_window_manager = false;
    managed_windows.clear();
    dock_windows.clear();
    std::signal(SIGTERM, stop_manager);
    std::signal(SIGINT, stop_manager);
    std::signal(SIGPIPE, SIG_IGN);
    std::signal(SIGCHLD, SIG_IGN);
    display = XOpenDisplay(nullptr);
    if (!display) {
        std::cerr << "Nodular: DISPLAY is unavailable\n";
        return 1;
    }

    root_window = DefaultRootWindow(display);
    screen_width = DisplayWidth(display, DefaultScreen(display));
    screen_height = DisplayHeight(display, DefaultScreen(display));

    XSetErrorHandler(x_error_handler);
    XSelectInput(display, root_window,
                 SubstructureRedirectMask | SubstructureNotifyMask | PropertyChangeMask | KeyPressMask);
    XSync(display, False);
    if (another_window_manager) {
        std::cerr << "Nodular: another window manager already owns the X11 root window\n";
        XCloseDisplay(display);
        return 2;
    }

    const unsigned int mod4 = Mod4Mask;
    XGrabKey(display, XKeysymToKeycode(display, XK_Return), mod4, root_window, True,
             GrabModeAsync, GrabModeAsync);
    XGrabKey(display, XKeysymToKeycode(display, XK_q), mod4, root_window, True,
             GrabModeAsync, GrabModeAsync);
    create_socket();
    chmod(socket_path.c_str(), 0600);
    set_wm_name();

    std::cout << "Nodular X11 window manager running on " << screen_width << 'x' << screen_height << '\n';
    while (running) {
        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(ConnectionNumber(display), &read_fds);
        FD_SET(socket_fd, &read_fds);
        const int max_fd = std::max(ConnectionNumber(display), socket_fd);
        timeval immediate{0, 0};
        if (select(max_fd + 1, &read_fds, nullptr, nullptr, XPending(display) ? &immediate : nullptr) < 0) {
            if (errno == EINTR) continue;
            break;
        }

        if (FD_ISSET(socket_fd, &read_fds)) {
            const int client = accept4(socket_fd, nullptr, nullptr, SOCK_CLOEXEC);
            if (client >= 0) {
                timeval timeout{1, 0};
                setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
                char buffer[256]{};
                const ssize_t length = read(client, buffer, sizeof(buffer) - 1);
                if (length > 0) {
                    std::string command(buffer, static_cast<std::size_t>(length));
                    command.erase(command.find_last_not_of("\r\n") + 1);
                    try { handle_command(client, command); XFlush(display); }
                    catch (...) { send_text(client, "invalid-command"); }
                }
                close(client);
            }
        }

        if (FD_ISSET(ConnectionNumber(display), &read_fds) || XPending(display)) {
            while (XPending(display)) {
                XEvent event{};
                XNextEvent(display, &event);
                if (event.type == MapRequest) {
                    if (is_dock(event.xmaprequest.window)) {
                        if (std::find(dock_windows.begin(), dock_windows.end(), event.xmaprequest.window) == dock_windows.end()) {
                            dock_windows.push_back(event.xmaprequest.window);
                        }
                        XMapWindow(display, event.xmaprequest.window);
                        XRaiseWindow(display, event.xmaprequest.window);
                    } else {
                        add_window(event.xmaprequest.window);
                    }
                } else if (event.type == UnmapNotify || event.type == DestroyNotify) {
                    remove_window(event.xunmap.window);
                } else if (event.type == ConfigureRequest) {
                    XWindowChanges changes{};
                    changes.x = event.xconfigurerequest.x;
                    changes.y = event.xconfigurerequest.y;
                    changes.width = event.xconfigurerequest.width;
                    changes.height = event.xconfigurerequest.height;
                    changes.border_width = event.xconfigurerequest.border_width;
                    changes.sibling = event.xconfigurerequest.above;
                    changes.stack_mode = event.xconfigurerequest.detail;
                    XConfigureWindow(display, event.xconfigurerequest.window,
                                     event.xconfigurerequest.value_mask, &changes);
                } else if (event.type == KeyPress) {
                    const KeySym key = XkbKeycodeToKeysym(display, event.xkey.keycode, 0, 0);
                    if (key == XK_Return) launch_terminal();
                    if (key == XK_q) {
                        const Window window = focused_window();
                        if (window != None) XKillClient(display, window);
                    }
                }
            }
        }
    }

    close(socket_fd);
    unlink(socket_path.c_str());
    XCloseDisplay(display);
    return 0;
}

// The X11 event loop runs in a dedicated Node process, never Electron's UI loop.
napi_value Run(napi_env env, napi_callback_info) {
    try {
        napi_value result;
        napi_create_int32(env, run_manager(), &result);
        return result;
    } catch (const std::exception &error) {
        napi_throw_error(env, nullptr, error.what());
        return nullptr;
    }
}

napi_value Init(napi_env env, napi_value exports) {
    napi_value run;
    napi_create_function(env, "run", NAPI_AUTO_LENGTH, Run, nullptr, &run);
    napi_set_named_property(env, exports, "run", run);
    return exports;
}
NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
