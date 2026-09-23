import { createRequire } from 'node:module'
import { join } from 'node:path'
import { root, slugPath } from './paths.js'

// Node's native-addon loader is the one necessary CommonJS interop boundary.
const loadAddon = createRequire(import.meta.url)
export async function native(slug) {
  return loadAddon(slugPath(join(root, 'build/Release'), slug, '.node'))
}
