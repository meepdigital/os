Read ./nodular.md. It's a conversation with ChatGPT about what I want you to make. Focus on the end of the conversation where the design becomes more clear.

I want you to build a new window manager, called nodular. Here are the constraints:

- its source code should be in ./nodular/src
- its built code should be in ./nodular/build
- Chromium/Blink shell
- uses a new folder in the root of the system at /node_modules
- uses Bootstrap 5
- should start with just a Bootstrap navbar at the bottom of the screen
- should be selectable at the Ubuntu start screen as an available window manager called Nodular
- should be built in a way so that the Chromium shell can launch native browser windows instead of Chromium processes
- should be tied into X11
- Blink should render everything
- V8 should be available and be used to make the desktop interactive
- should be written in as low of level code as possible, but still expose API's and functionality accessible with V8 JavaScript
- should be controllable by ESM modules

I don't fully understand how this all works, so the below constraints should be taken with a grain of salt:

- include a NPM module that interacts with X11 or the Chromium shell
- be able to control windows, panels, applets, other applets, with JavaScript applets
