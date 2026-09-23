export const initializeMenu = (api, menu, launcher) => {
    const setOpen = open => {
        menu.classList.toggle('show', open)
        launcher.setAttribute('aria-expanded', String(open))
    }

    document.querySelectorAll('[data-application]').forEach(item => item.addEventListener('click', async () => {
        await api.launch(item.dataset.application)
        setOpen(false)
    }))

    document.addEventListener('click', event => {
        if (!launcher.contains(event.target) && !menu.contains(event.target)) setOpen(false)
    })

    return setOpen
}
