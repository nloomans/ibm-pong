const WebSocketServer = require('websocket').server;
const EventEmitter = require('events');

function decode(string) {
  return string.split('').map(char => char.charCodeAt(0));
}

class Game {}

class ClientRepresentor extends EventEmitter {
  constructor(connection) {
    super();

    this.connection = connection;

    this.onMessage = this.onMessage.bind(this);

    this.connection.on('message', this.onMessage);
    this.connection.on('close', () => { console.log(`Peer ${this.connection.remoteAddress} disconnected.`); });
  }

  attachToGame(game) {
    this.game = game;
    this.sendMessage('e');
  }

  // eslint-disable-next-line class-methods-use-this
  onMessage(utf8EncodedMessage) {
    const message = decode(utf8EncodedMessage.utf8Data);
    console.log(`New message ${message}`);
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
    };

    this.server.on('request', (request) => {
      const connection = request.accept(null, request.origin);
      console.log('Connection accepted.');

      const clientRepresentor = new ClientRepresentor(connection);
      this.state.pendingClients.push(clientRepresentor);
      if (this.state.pendingClients.length === 2) {
        const game = new Game();
        this.state.games.push(game);
        this.state.pendingClients.forEach(pendingClient => pendingClient.attachToGame(game));
        this.state.pendingClients = [];
      }

      console.log(this.state);
    });
  }
}

module.exports = Server;
