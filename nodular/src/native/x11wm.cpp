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
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <vector>

namespace {

constexpr unsigned int titlebar_height = 26;
constexpr unsigned int close_button_width = 30;

struct Client {
    Window client;
    Window frame;
    int x;
    int y;
    unsigned int width;
    unsigned int height;
};

Display *display = nullptr;
Window root_window = 0;
int screen_width = 0;
int screen_height = 0;
int panel_height = 38;
int socket_fd = -1;
std::string socket_path;
volatile sig_atomic_t running = 1;
std::vector<Client> clients;
std::vector<Window> dock_windows;
Window dragging_frame = None;
int drag_offset_x = 0;
int drag_offset_y = 0;

Atom wm_protocols_atom = None;
Atom wm_delete_atom = None;
Atom net_wm_name_atom = None;
Atom utf8_string_atom = None;
Atom wm_name_atom = None;
Atom net_wm_window_type_atom = None;
Atom net_wm_window_type_dock_atom = None;

bool another_window_manager = false;

void stop_manager(int) { running = 0; }

int x_error_handler(Display *, XErrorEvent *event) {
    if (event->error_code == BadAccess) another_window_manager = true;
    return 0;
}

Client *find_client(Window window) {
    for (Client &client : clients) {
        if (client.client == window || client.frame == window) return &client;
    }
    return nullptr;
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

std::string window_title(Window window) {
    Atom actual_type = None;
    int format = 0;
    unsigned long item_count = 0;
    unsigned long bytes_after = 0;
    unsigned char *data = nullptr;
    std::string title;

    const int status = XGetWindowProperty(
        display, window, net_wm_name_atom, 0, 1024, False, utf8_string_atom,
        &actual_type, &format, &item_count, &bytes_after, &data);
    if (status == Success && data != nullptr && item_count > 0)
        title.assign(reinterpret_cast<char *>(data), item_count);
    if (data != nullptr) XFree(data);

    if (title.empty()) {
        char *legacy_title = nullptr;
        if (XFetchName(display, window, &legacy_title) && legacy_title != nullptr) {
            title = legacy_title;
            XFree(legacy_title);
        }
    }

    if (title.empty()) title = "Nodular window";
    return title;
}

void draw_frame(const Client &client) {
    XClearWindow(display, client.frame);
    XGCValues values{};
    GC graphics = XCreateGC(display, client.frame, 0, &values);
    if (graphics == nullptr) return;

    XSetForeground(display, graphics, WhitePixel(display, DefaultScreen(display)));
    const std::string title = window_title(client.client);
    const std::string visible_title = title.substr(0, std::max<std::size_t>(1, client.width / 10));
    XDrawString(display, client.frame, graphics, 8, 18, visible_title.c_str(), static_cast<int>(visible_title.size()));
    const char close_label[] = "x";
    XDrawString(display, client.frame, graphics, static_cast<int>(client.width) - 18, 18, close_label, 1);
    XFreeGC(display, graphics);
}

void focus_client(Client &client) {
    XSetInputFocus(display, client.client, RevertToPointerRoot, CurrentTime);
    XRaiseWindow(display, client.frame);
    XFlush(display);
}

void send_delete(Client &client) {
    Atom *protocols = nullptr;
    int protocol_count = 0;
    bool supports_delete = false;
    if (XGetWMProtocols(display, client.client, &protocols, &protocol_count)) {
        for (int index = 0; index < protocol_count; ++index)
            if (protocols[index] == wm_delete_atom) supports_delete = true;
        XFree(protocols);
    }

    if (!supports_delete) {
        XKillClient(display, client.client);
        return;
    }

    XEvent event{};
    event.xclient.type = ClientMessage;
    event.xclient.window = client.client;
    event.xclient.message_type = wm_protocols_atom;
    event.xclient.format = 32;
    event.xclient.data.l[0] = static_cast<long>(wm_delete_atom);
    event.xclient.data.l[1] = CurrentTime;
    XSendEvent(display, client.client, False, NoEventMask, &event);
}

void send_configure_notify(const Client &client) {
    XEvent event{};
    event.xconfigure.type = ConfigureNotify;
    event.xconfigure.display = display;
    event.xconfigure.event = client.client;
    event.xconfigure.window = client.client;
    event.xconfigure.x = client.x;
    event.xconfigure.y = client.y + static_cast<int>(titlebar_height);
    event.xconfigure.width = static_cast<int>(client.width);
    event.xconfigure.height = static_cast<int>(client.height);
    event.xconfigure.border_width = 0;
    event.xconfigure.above = None;
    event.xconfigure.override_redirect = False;
    XSendEvent(display, client.client, False, StructureNotifyMask, &event);
}

void resize_client(Client &client, unsigned int width, unsigned int height) {
    client.width = std::max(1U, width);
    client.height = std::max(1U, height);
    XResizeWindow(display, client.frame, client.width, client.height + titlebar_height);
    XMoveResizeWindow(display, client.client, 0, titlebar_height, client.width, client.height);
    draw_frame(client);
    send_configure_notify(client);
}

void arrange();

void remove_client(Window window) {
    const auto iterator = std::find_if(clients.begin(), clients.end(), [window](const Client &client) {
        return client.client == window || client.frame == window;
    });
    if (iterator == clients.end()) return;
    if (dragging_frame == iterator->frame) dragging_frame = None;
    if (iterator->frame != None) XDestroyWindow(display, iterator->frame);
    clients.erase(iterator);
    arrange();
}

void arrange() {
    const unsigned int usable_height = static_cast<unsigned int>(std::max(1, screen_height - panel_height));
    if (clients.empty()) {
        for (const Window dock : dock_windows) XRaiseWindow(display, dock);
        XFlush(display);
        return;
    }

    const unsigned int client_height = std::max(1U, usable_height / static_cast<unsigned int>(clients.size()));
    for (std::size_t index = 0; index < clients.size(); ++index) {
        Client &client = clients[index];
        const int y = static_cast<int>(index * client_height);
        const unsigned int frame_height = index + 1 == clients.size()
            ? usable_height - static_cast<unsigned int>(y)
            : client_height;
        client.x = 0;
        client.y = y;
        client.width = static_cast<unsigned int>(screen_width);
        client.height = std::max(1U, frame_height - titlebar_height);
        XMoveResizeWindow(display, client.frame, client.x, client.y, client.width, frame_height);
        XMoveResizeWindow(display, client.client, 0, titlebar_height, client.width, client.height);
        draw_frame(client);
        XMapWindow(display, client.frame);
        XMapWindow(display, client.client);
        send_configure_notify(client);
    }
    for (const Window dock : dock_windows) XRaiseWindow(display, dock);
    XFlush(display);
}

bool is_dock(Window window) {
    Atom actual_type = None;
    int format = 0;
    unsigned long item_count = 0;
    unsigned long bytes_after = 0;
    unsigned char *data = nullptr;
    const int status = XGetWindowProperty(
        display, window, net_wm_window_type_atom, 0, 8, False, XA_ATOM,
        &actual_type, &format, &item_count, &bytes_after, &data);
    bool dock = false;
    if (status == Success && data != nullptr) {
        const auto *types = reinterpret_cast<const Atom *>(data);
        for (unsigned long index = 0; index < item_count; ++index)
            if (types[index] == net_wm_window_type_dock_atom) dock = true;
    }
    if (data != nullptr) XFree(data);
    return dock;
}

void manage_window(Window window) {
    Client *existing = find_client(window);
    if (existing != nullptr) {
        XMapWindow(display, existing->frame);
        XMapWindow(display, existing->client);
        return;
    }

    XWindowAttributes attributes{};
    if (!XGetWindowAttributes(display, window, &attributes)) return;
    Client client{window, None, attributes.x, attributes.y,
                  static_cast<unsigned int>(std::max(1, attributes.width)),
                  static_cast<unsigned int>(std::max(1, attributes.height))};
    client.frame = XCreateSimpleWindow(
        display, root_window, client.x, client.y, client.width,
        client.height + titlebar_height, 1,
        BlackPixel(display, DefaultScreen(display)),
        BlackPixel(display, DefaultScreen(display)));
    if (client.frame == None) return;

    XSelectInput(display, client.frame,
                 ExposureMask | ButtonPressMask | ButtonReleaseMask |
                 PointerMotionMask | EnterWindowMask | FocusChangeMask |
                 SubstructureNotifyMask);
    XSelectInput(display, window, PropertyChangeMask | StructureNotifyMask);
    XAddToSaveSet(display, window);
    XReparentWindow(display, window, client.frame, 0, titlebar_height);
    clients.push_back(client);
    resize_client(clients.back(), clients.back().width, clients.back().height);
    XMapWindow(display, clients.back().frame);
    XMapWindow(display, clients.back().client);
    arrange();
}

Window focused_window() {
    Window focused = None;
    int revert = RevertToPointerRoot;
    XGetInputFocus(display, &focused, &revert);
    Client *client = find_client(focused);
    return client == nullptr ? (clients.empty() ? None : clients.back().client) : client->client;
}

void launch_terminal() {
    const pid_t pid = fork();
    if (pid == 0) {
        close(ConnectionNumber(display));
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
        for (std::size_t index = 0; index < clients.size(); ++index) {
            if (index != 0) result << ' ';
            result << clients[index].client;
        }
        send_text(client_fd, result.str());
    } else if (command.rfind("focus ", 0) == 0) {
        const Window window = static_cast<Window>(std::stoul(command.substr(6)));
        Client *client = find_client(window);
        if (client != nullptr) {
            focus_client(*client);
            send_text(client_fd, "ok");
        } else {
            send_text(client_fd, "unknown-window");
        }
    } else if (command == "close") {
        const Window window = focused_window();
        Client *client = find_client(window);
        if (client != nullptr) send_delete(*client);
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
    if (bind(socket_fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) < 0 || listen(socket_fd, 8) < 0)
        throw std::runtime_error("cannot bind Nodular socket");
}

void initialize_atoms() {
    wm_protocols_atom = XInternAtom(display, "WM_PROTOCOLS", False);
    wm_delete_atom = XInternAtom(display, "WM_DELETE_WINDOW", False);
    net_wm_name_atom = XInternAtom(display, "_NET_WM_NAME", False);
    utf8_string_atom = XInternAtom(display, "UTF8_STRING", False);
    wm_name_atom = XInternAtom(display, "WM_NAME", False);
    net_wm_window_type_atom = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
    net_wm_window_type_dock_atom = XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", False);
}

void handle_frame_event(XEvent &event) {
    Client *client = find_client(event.xany.window);
    if (client == nullptr) return;
    if (event.type == Expose && event.xexpose.count == 0) {
        draw_frame(*client);
    } else if (event.type == ButtonPress) {
        focus_client(*client);
        if (event.xbutton.y < static_cast<int>(titlebar_height)) {
            if (event.xbutton.x >= static_cast<int>(client->width - close_button_width)) {
                send_delete(*client);
            } else {
                dragging_frame = client->frame;
                drag_offset_x = event.xbutton.x_root - client->x;
                drag_offset_y = event.xbutton.y_root - client->y;
            }
        }
    } else if (event.type == MotionNotify && dragging_frame == client->frame) {
        client->x = event.xmotion.x_root - drag_offset_x;
        client->y = event.xmotion.y_root - drag_offset_y;
        XMoveWindow(display, client->frame, client->x, client->y);
    } else if (event.type == ButtonRelease && dragging_frame == client->frame) {
        dragging_frame = None;
    }
}

} // namespace

int run_manager() {
    const char *configured_socket = std::getenv("NODULAR_WM_SOCKET");
    if (!configured_socket) throw std::runtime_error("NODULAR_WM_SOCKET is required");
    socket_path = configured_socket;
    running = 1;
    another_window_manager = false;
    clients.clear();
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
    initialize_atoms();
    XSetErrorHandler(x_error_handler);
    XSelectInput(display, root_window,
                 SubstructureRedirectMask | SubstructureNotifyMask |
                 PropertyChangeMask | KeyPressMask);
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
            const int socket_client = accept4(socket_fd, nullptr, nullptr, SOCK_CLOEXEC);
            if (socket_client >= 0) {
                timeval timeout{1, 0};
                setsockopt(socket_client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
                char buffer[256]{};
                const ssize_t length = read(socket_client, buffer, sizeof(buffer) - 1);
                if (length > 0) {
                    std::string command(buffer, static_cast<std::size_t>(length));
                    const std::size_t end = command.find_last_not_of("\r\n");
                    if (end != std::string::npos) command.erase(end + 1);
                    try {
                        handle_command(socket_client, command);
                        XFlush(display);
                    } catch (...) {
                        send_text(socket_client, "invalid-command");
                    }
                }
                close(socket_client);
            }
        }

        if (FD_ISSET(ConnectionNumber(display), &read_fds) || XPending(display)) {
            while (XPending(display)) {
                XEvent event{};
                XNextEvent(display, &event);
                if (event.type == MapRequest) {
                    if (is_dock(event.xmaprequest.window)) {
                        if (std::find(dock_windows.begin(), dock_windows.end(), event.xmaprequest.window) == dock_windows.end())
                            dock_windows.push_back(event.xmaprequest.window);
                        XMapWindow(display, event.xmaprequest.window);
                        XRaiseWindow(display, event.xmaprequest.window);
                    } else {
                        manage_window(event.xmaprequest.window);
                    }
                } else if (event.type == UnmapNotify) {
                    Client *client = find_client(event.xunmap.window);
                    if (client != nullptr && event.xunmap.event == client->frame)
                        remove_client(event.xunmap.window);
                } else if (event.type == DestroyNotify) {
                    remove_client(event.xdestroywindow.window);
                } else if (event.type == ConfigureRequest) {
                    Client *client = find_client(event.xconfigurerequest.window);
                    if (client == nullptr) {
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
                    } else {
                        const unsigned int width = (event.xconfigurerequest.value_mask & CWWidth)
                            ? static_cast<unsigned int>(event.xconfigurerequest.width) : client->width;
                        const unsigned int height = (event.xconfigurerequest.value_mask & CWHeight)
                            ? static_cast<unsigned int>(event.xconfigurerequest.height) : client->height;
                        resize_client(*client, width, height);
                    }
                } else if (event.type == PropertyNotify) {
                    Client *client = find_client(event.xproperty.window);
                    if (client != nullptr && (event.xproperty.atom == wm_name_atom || event.xproperty.atom == net_wm_name_atom))
                        draw_frame(*client);
                } else if (event.type == KeyPress) {
                    const KeySym key = XkbKeycodeToKeysym(display, event.xkey.keycode, 0, 0);
                    if (key == XK_Return) launch_terminal();
                    if (key == XK_q) {
                        const Window window = focused_window();
                        Client *client = find_client(window);
                        if (client != nullptr) send_delete(*client);
                    }
                } else if (event.type == ClientMessage && event.xclient.message_type == wm_protocols_atom) {
                    Client *client = find_client(event.xclient.window);
                    if (client != nullptr && static_cast<Atom>(event.xclient.data.l[0]) == wm_delete_atom)
                        remove_client(client->client);
                } else if (event.type == Expose || event.type == ButtonPress ||
                           event.type == ButtonRelease || event.type == MotionNotify) {
                    handle_frame_event(event);
                }
            }
        }
    }

    if (socket_fd >= 0) close(socket_fd);
    if (!socket_path.empty()) unlink(socket_path.c_str());
    XCloseDisplay(display);
    return 0;
}

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
