import './env.js'
import { native } from './native.js'
const x11 = await native('x11wm')
process.exitCode = x11.run()
