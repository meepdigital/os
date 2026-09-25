import '../assets/bootstrap/dist/js/bootstrap.bundle.js'
import '../assets/style.scss'
import '../assets/style.less'
import { initializeWindows } from './components/windows.js'
import { initializeLauncher } from './components/launcher.js'
import { initializeMenu } from './components/menu.js'

const initialize = () => {

    const api = window.nodular
    const windows = document.querySelector('#windows')
    const launcher = document.querySelector('#launcher')
    const menu = document.querySelector('#application-menu')

    if (!api || !windows || !launcher || !menu) return

    const setOpen = initializeMenu(api, menu, launcher)
    initializeLauncher(launcher, menu, setOpen)
    initializeWindows(api, windows)
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize, { once: true })
else initialize()
