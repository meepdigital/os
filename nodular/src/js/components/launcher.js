export const initializeLauncher = (launcher, menu, setOpen) => {
    launcher.addEventListener('click', () => setOpen(!menu.classList.contains('show')))
}
