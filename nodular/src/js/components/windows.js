export const initializeWindows = (api, windows) => {
    const terminal = document.querySelector('#terminal')
    const close = document.querySelector('#close')

    if (terminal) terminal.addEventListener('click', () => api.wm('launch-terminal'))
    if (close) close.addEventListener('click', () => api.wm('close'))

    const refresh = async () => {
        try {
            const ids = (await api.wm('windows')).split(/\s+/).filter(Boolean)
            windows.textContent = ids.length ? `${ids.length} managed window${ids.length === 1 ? '' : 's'}` : 'No managed windows'
        } catch {
            windows.textContent = 'X11 manager unavailable'
        }
    }

    void refresh()
    setInterval(refresh, 1000)
}
