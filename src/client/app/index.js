const Elm = require('./Main.elm');

const app = Elm.Main.fullscreen({
  // Give Elm the protocol for the web socket server to connect to.
  // E.g. ws://localhost:8000
  wsserver: (window.location.protocol.includes('https') ? 'wss://' : 'ws://') + window.location.host,
});

// Send keyboard events of the entire page to end.
// This is because elm can't acces the document object by design. We we need a
// bit of JS for this.
window.document.addEventListener('keydown', function (event) {
  app.ports.onKeyDown.send(event.key);
});

// Indirectly send the Tick msg to Elm every animation frame. Also tell elm how
// much time has passed since then.
let prevTick = new Date().valueOf();
function tick() {
  app.ports.tick.send(new Date().valueOf() - prevTick);
  prevTick = new Date().valueOf();
  window.requestAnimationFrame(tick);
}

tick();
