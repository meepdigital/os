import './core/env.js'
import { app, BrowserWindow, screen } from 'electron'
import { mkdir, writeFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { join } from 'node:path'
import { render } from './core/twig.js'
import { root, runtime } from './core/paths.js'
import { registerIpc } from './core/ipc.js'

registerIpc()

export let layout

app.whenReady().then(async () => {

  layout = await render('layout', {
    stylesheet: pathToFileURL(join(root, 'build/assets/style.css')).href,
    script: pathToFileURL(join(root, 'build/js/app.mjs')).href,
  })

  const { x, y, width, height } = screen.getPrimaryDisplay().bounds
  const directory = runtime
  await mkdir(directory, { recursive: true })
  const file = join(directory, `layout-${process.pid}.html`)
  await writeFile(file, layout)

  const window = new BrowserWindow({
    
    width, 
    height: 294,
    x,
    y: y + height - 294,
    
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    resizable: false,
    movable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    type: 'dock',

    webPreferences: {
      preload: join(root, 'build/js/preload.mjs'),
      contextIsolation: true, nodeIntegration: false, sandbox: false, devTools: true,
    },

  })

  window.setBackgroundColor('#00000000')
  await window.loadFile(file)
  window.setAlwaysOnTop(true, 'floating')

  if (process.env.NODULAR_DEVTOOLS === '1') window.webContents.openDevTools({ mode: 'detach' })

}).catch(error => {

  console.error(error)
  app.exit(1)
  
})

app.on('window-all-closed', () => app.quit())
