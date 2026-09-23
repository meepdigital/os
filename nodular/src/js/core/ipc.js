import { BrowserWindow, ipcMain } from 'electron'
import { command } from '../components/window.js'
import { launchApplication } from './application.js'

export function registerIpc() {

  ipcMain.handle('nodular-wm', (_event, message) => {
    if (!/^(windows|close|launch-terminal|focus [0-9]+)$/.test(message)) {
      throw new Error('Invalid window command')
    }
    return command(message)
  })

  ipcMain.handle('launch-application', (_event, application) => launchApplication(application))
}
