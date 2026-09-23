import './env.js'
import { spawn } from 'node:child_process'
import { mkdtemp, rm } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { setTimeout as delay } from 'node:timers/promises'
import electron from 'electron'
import { root } from './paths.js'
import { command } from '../components/window.js'

if (!process.env.DISPLAY) throw new Error('DISPLAY is required use npm run xephyr')

const runtime = await mkdtemp(join(tmpdir(), 'nodular-'))

process.env.NODULAR_WM_SOCKET = join(runtime, 'wm.sock')
process.env.NODULAR_RUNTIME_DIR = runtime

const children = new Set()
let stopping = false

async function stop(code = 0) {

  if (stopping) return
  stopping = true

  for (const child of children) child.kill('SIGTERM')

  await Promise.race([
    Promise.all([...children].map(child => new Promise(resolve => {
      if (child.exitCode !== null || child.signalCode) resolve()
      else child.once('exit', resolve)
    }))),
    delay(2000),
  ])

  for (const child of children) if (child.exitCode === null && !child.signalCode) child.kill('SIGKILL')

  await rm(runtime, { recursive: true, force: true })

  process.exit(code)

}

function launch(binary, args) {
  
  const child = spawn(binary, args, { stdio: 'inherit', env: process.env })
  
  children.add(child)
  child.on('error', error => { console.error(error); void stop(1) })
  child.on('exit', code => { if (!stopping) void stop(code ?? 1) })

  return child

}

process.on('SIGINT', () => void stop())
process.on('SIGTERM', () => void stop())

launch(process.execPath, [join(root, 'build/js/wm.mjs')])

try {
  
  let ready = false

  for (let attempt = 0; attempt < 100 && !stopping; attempt++) {
  
    try { ready = await command('ping') === 'pong' } catch { /* Waiting for socket. */ }
    if (ready) break
    await delay(50)

  }
  
  if (!ready) throw new Error('X11 manager did not become ready')
  const background = process.env.NODULAR_BACKGROUND || join(root, 'src/assets/bg.svg')
  
  if (background && existsSync(background)) {
    const setter = spawn('feh', ['--no-fehbg', '--bg-fill', background], { stdio: 'inherit' })
    setter.on('error', console.error)
  }
  
  const electronFlags = process.env.NODULAR_ELECTRON_NO_SANDBOX === '1' ? ['--no-sandbox'] : []
  launch(process.env.NODULAR_ELECTRON || electron, [...electronFlags, join(root, 'build/js/main.mjs')])

} catch (error) {

  console.error(error)
  await stop(1)

}
