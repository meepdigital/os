import './env.js'
import { contextBridge, ipcRenderer } from 'electron'

const api = {
  wm: command => ipcRenderer.invoke('nodular-wm', command),
  launch: application => ipcRenderer.invoke('launch-application', application),
}

contextBridge.exposeInMainWorld('nodular', api)
