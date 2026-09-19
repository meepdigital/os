import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('nodular', {
  wm: (command) => ipcRenderer.invoke('nodular-wm', command),
  launch: (application) => ipcRenderer.invoke('launch-application', application),
});
