const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('meepInstaller', {
  isRoot: () => ipcRenderer.invoke('system:is-root'),
  listBlockDevices: () => ipcRenderer.invoke('system:list-block-devices'),
  collectDrivers: () => ipcRenderer.invoke('system:collect-drivers'),
  executeInstall: (payload) => ipcRenderer.invoke('installer:execute', payload),
  returnToOs: () => ipcRenderer.invoke('window:return-to-os'),
});
