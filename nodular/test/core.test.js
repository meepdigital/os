import { env } from '../src/js/core/env.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, rm, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { root } from '../src/js/core/paths.js';
import { render, interpret } from '../src/js/core/twig.js';
import { native } from '../src/js/core/native.js';

const slug = `test-${process.pid}`;
  const directory = join(root, 'src/templates', slug);
  const extensions = join(root, 'src/extensions', slug, 'nested');

test('Twig rendering, ES module interpretation, failures, and slug boundaries', async () => {
  await mkdir(directory, { recursive: true });
  await mkdir(join(root, 'tmp'), { recursive: true });
  const before = new Set(await readdir(join(root, 'tmp')));
  try {
    await mkdir(extensions, { recursive: true });
    await writeFile(join(extensions, 'extension.php'), String.raw`<?php
return static function (\Twig\Environment $twig): void {
    $twig->addFunction(new \Twig\TwigFunction('nodular_test_extension', static fn () => 'extension loaded'));
};
`);
    await writeFile(join(directory, 'extension.html.twig'), '{{ nodular_test_extension() }}');
    await writeFile(join(directory, 'extension.js.twig'), 'export default {{ nodular_test_extension()|json_encode|raw }};');
    assert.equal(await render(`${slug}/extension`), 'extension loaded');
    assert.equal(await interpret(`${slug}/extension`), 'extension loaded');
    await writeFile(join(directory, 'html.html.twig'), '{{ test }}');
    await writeFile(join(directory, 'module.js.twig'), 'export default {{ test|json_encode|raw }};');
    await writeFile(join(directory, 'named.js.twig'), 'export const answer = {{ answer }};');
    await writeFile(join(directory, 'invalid.js.twig'), 'export default (;');
    assert.equal(await render(`${slug}/html`, { test: '<hello>' }), '&lt;hello&gt;');
    await writeFile(join(directory, 'env.html.twig'), '{{ env.NODULAR_ELECTRON_NO_SANDBOX }}');
    await writeFile(join(directory, 'env.js.twig'), 'export default {{ env|json_encode|raw }};');
    assert.equal(await render(`${slug}/env`, { env: {} }), env.NODULAR_ELECTRON_NO_SANDBOX);
    const interpretedEnv = await interpret(`${slug}/env`);
    assert.ok(Object.keys(env).every(key => interpretedEnv[key] === env[key]));
    assert.ok(Object.keys(env).every(key => process.env[key] === env[key]));
    assert.deepEqual(await interpret(`${slug}/module`, { test: { enabled: true, text: "a'b" } }), { enabled: true, text: "a'b" });
    assert.equal((await interpret(`${slug}/named`, { answer: 42 })).answer, 42);
    assert.equal(await interpret(`${slug}/module`, { test: false }), false);
    await assert.rejects(interpret(`${slug}/invalid`), SyntaxError);
    await assert.rejects(render(`${slug}/missing`));
    assert.throws(() => render('../escape'), TypeError);
    await assert.rejects(native('../escape'), TypeError);
  } finally {
    await rm(directory, { recursive: true, force: true });
    await rm(join(root, 'src/extensions', slug), { recursive: true, force: true });
    for (const file of await readdir(join(root, 'tmp'))) {
      if (!before.has(file) && /^[0-9a-f-]{36}\.js$/.test(file)) await rm(join(root, 'tmp', file));
    }
  }
});

test('native addon loads without opening a display', async () => {
  const x11 = await native('x11wm');
  assert.equal(typeof x11.run, 'function');
});


test('application layout owns styles and component markup stays partial', async () => {
  const html = await render('layout', { stylesheet: 'app.css', script: 'app.mjs' });
  assert.equal((html.match(/<!doctype html>/gi) || []).length, 1);
  assert.equal((html.match(/href="app.css"/g) || []).length, 1);
  assert.equal((html.match(/src="app.mjs"/g) || []).length, 1);
  assert.ok(html.includes('id="terminal"') && html.includes('id="close"'));
  const navbar = await render('components/navbar');
  assert.ok(!/<(?:html|head|link|style)\b/i.test(navbar));
});
