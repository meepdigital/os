import { existsSync } from 'node:fs'
import { spawn } from 'node:child_process'
import { command } from '../components/window.js'

export function launchApplication(application) {
  if (application === 'terminal') return command('launch-terminal')

  const home = process.env.HOME || '/tmp'
  const applications = {
    files: existsSync('/usr/bin/nautilus')
      ? ['/usr/bin/nautilus', ['--new-window', home]]
      : existsSync('/usr/bin/nemo')
        ? ['/usr/bin/nemo', [home]]
        : ['/usr/bin/xdg-open', [home]],
    browser: ['/usr/bin/xdg-open', ['https://www.google.com']],
  }
  const launch = applications[application]
  if (!launch) throw new Error(`Unknown application: ${application}`)

  const child = spawn(launch[0], launch[1], { detached: true, stdio: 'ignore' })
  child.unref()
  return 'ok'
}

