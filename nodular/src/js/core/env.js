import dotenv from 'dotenv'
import { join } from 'node:path'
import { root } from './paths.js'

// Webpack captures only repository .env keys, never the whole host environment.
const buildValues = typeof __NODULAR_BUILD_ENV__ === 'undefined' ? {} : __NODULAR_BUILD_ENV__
const result = dotenv.config({ path: join(root, '..', '.env'), quiet: true })
if (result.error && result.error.code !== 'ENOENT') throw result.error
const defaults = { ...buildValues, ...result.parsed }
for (const [key, value] of Object.entries(defaults)) process.env[key] ??= value

// Explicit process/command-line overrides take precedence over .env defaults.
export const env = Object.freeze(Object.fromEntries(
  Object.keys(defaults).map(key => [key, process.env[key]]),
))
