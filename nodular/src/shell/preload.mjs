import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('nodular', {
  wm: (command) => ipcRenderer.invoke('nodular-wm', command),
});
