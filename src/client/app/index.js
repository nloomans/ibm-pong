const Elm = require('./Main.elm');

const app = Elm.Main.fullscreen({
  wsserver: (window.location.protocol.includes('https') ? 'wss://' : 'ws://') + window.location.host,
});

window.document.addEventListener('keydown', (event) => {
  app.ports.onKeyDown.send(event.key);
});
