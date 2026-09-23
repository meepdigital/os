import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, parse } from 'node:path'
import { fileURLToPath } from 'node:url'

// Works from both src/js and webpack's build/js output, independent of cwd.
let directory = dirname(fileURLToPath(import.meta.url))
while (directory !== parse(directory).root) {
  const manifest = join(directory, 'package.json')
  if (existsSync(manifest) && JSON.parse(readFileSync(manifest, 'utf8')).name === 'nodular') break
  directory = dirname(directory)
}
if (directory === parse(directory).root) throw new Error('Cannot locate Nodular package root')
export const root = directory
export const runtime = process.env.NODULAR_RUNTIME_DIR || join(root, 'tmp')

export function slugPath(base, slug, suffix = '') {
  if (typeof slug !== 'string' || !/^[\w-]+(?:\/[\w-]+)*$/.test(slug)) {
    throw new TypeError('Expected a relative path slug without an extension or traversal')
  }
  return join(base, `${slug}${suffix}`)
}
