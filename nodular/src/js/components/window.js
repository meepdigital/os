import net from 'node:net'

export function command(message) {
  const socket = process.env.NODULAR_WM_SOCKET
  if (!socket) return Promise.reject(new Error('NODULAR_WM_SOCKET is not configured'))
  return new Promise((resolve, reject) => {
    const connection = net.createConnection(socket)
    let response = ''
    connection.setTimeout(2000, () => connection.destroy(new Error('X11 manager timed out')))
    connection.on('connect', () => connection.end(`${message}\n`))
    connection.on('data', chunk => { response += chunk })
    connection.on('end', () => resolve(response.trim()))
    connection.on('error', reject)
  })
}

export class X11Window {
  constructor(id) {
    if (!Number.isSafeInteger(Number(id)) || Number(id) <= 0) throw new TypeError('Invalid X11 window ID')
    this.id = Number(id)
  }
  async focus() {
    const result = await command(`focus ${this.id}`)
    if (result !== 'ok') throw new Error(result)
    return this
  }
  static async list() {
    const result = await command('windows')
    return result ? result.split(/\s+/).map(id => new X11Window(id)) : []
  }
  static closeFocused() { return command('close') }
  static launchTerminal() { return command('launch-terminal') }
}
export default X11Window
