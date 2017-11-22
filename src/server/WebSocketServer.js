const WebSocketServer = require('websocket').server;
const EventEmitter = require('events');

function decode(string) {
  return string.split('').map(char => char.charCodeAt(0));
}

function encode(array) {
  return array.map(int => String.fromCharCode(int)).join('');
}

class Game {}

class ClientRepresentor extends EventEmitter {
  constructor(connection) {
    super();

    this.connection = connection;

    this.onMessage = this.onMessage.bind(this);
    this.onClose = this.onClose.bind(this);

    this.connection.on('message', this.onMessage);
    this.connection.on('close', this.onClose);

    // Ensure that the client is in pending mode.
    this.sendMessage(encode([102]));
  }

  /**
   * attachToGame
   * @param {*} game The game object.
   * @param {*} player Can be 1 or 2. Signifies whenever or not this is player one or player two.
   */
  attachToGame(game, player) {
    this.game = game;
    this.player = player;
    this.sendMessage(encode([101]));
  }

  otherClientDisconnected() {
    this.sendMessage(encode([102]));
  }

  // eslint-disable-next-line class-methods-use-this
  onMessage(utf8EncodedMessage) {
    const message = decode(utf8EncodedMessage.utf8Data);
    console.log(`New message ${message}`);
  }

  onClose() {
    console.log(`Peer ${this.connection.remoteAddress} disconnected.`);
    this.emit('close');
  }

  sendMessage(byteArray) {
    // TODO: encode message
    this.connection.sendUTF(byteArray);
  }
}

class Server {
  constructor(server) {
    this.server = new WebSocketServer({
      httpServer: server,
      autoAcceptConnections: false,
    });

    this.state = {
      games: [],
      pendingClients: [],
      clients: [],
    };

    this.server.on('request', (request) => {
      const connection = request.accept(null, request.origin);
      console.log('Connection accepted.');

      const clientRepresentor = new ClientRepresentor(connection);
      this.state.pendingClients.push(clientRepresentor);
      this.state.clients.push(clientRepresentor);

      if (this.state.pendingClients.length === 2) {
        const game = new Game();
        this.state.games.push(game);

        this.state.pendingClients[0].attachToGame(game, 1);
        this.state.pendingClients[1].attachToGame(game, 2);
        this.state.pendingClients = [];
      }

      clientRepresentor.on('close', () => {
        for (let i = 0; i < this.state.pendingClients.length; i += 1) {
          if (clientRepresentor === this.state.pendingClients[i]) {
            this.state.pendingClients.splice(i, 1);
            i -= 1;
          }
        }

        for (let i = 0; i < this.state.clients.length; i += 1) {
          if (clientRepresentor === this.state.clients[i]) {
            this.state.clients.splice(i, 1);
            i -= 1;
          } else if (clientRepresentor.game === this.state.clients[i].game) {
            this.state.clients[i].otherClientDisconnected();
            this.state.pendingClients.push(this.state.clients[i]);
          }
        }

        for (let i = 0; i < this.state.games.length; i += 1) {
          if (clientRepresentor.game === this.state.games[i]) {
            this.state.games.splice(i, 1);
            i -= 1;
          }
        }
      });

      console.log(this.state);
    });
  }
}

module.exports = Server;
