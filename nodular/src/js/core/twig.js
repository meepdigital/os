import { env } from './env.js'
import { renderFile } from 'node-twig'
import { v4 as uuid } from 'uuid'
import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { root, runtime, slugPath } from './paths.js'

function template(slug, context, suffix) {
  const templates = join(root, 'src/templates')
  const entry = slugPath(templates, slug, suffix)
  return new Promise((resolve, reject) => {
    renderFile(entry, { root: templates, context: { ...context, env } }, (error, output) => {
      if (error) reject(error instanceof Error ? error : new Error(String(error)))
      else resolve(output)
    })
  })
}

export function render(slug, context = {}) {
  return template(slug, context, '.html.twig')
}

// Trusted project templates only: generated modules have full Node privileges.
export async function interpret(slug, context = {}) {
  const code = await template(slug, context, '.js.twig')
  const temporary = runtime
  await mkdir(temporary, { recursive: true, mode: 0o700 })
  const file = join(temporary, `${uuid()}.js`)
  await writeFile(file, code, { flag: 'wx', mode: 0o600 })
  const module = await import(/* webpackIgnore: true */ pathToFileURL(file).href)
  return Object.hasOwn(module, 'default') ? module.default : module
}
