import { Controller } from '@hotwired/stimulus'
import { createConsumer } from '@rails/actioncable'

// Connects to data-controller="game-connection"
export default class extends Controller {
  static values = { code: String }

  connect() {
    console.log(`Connecting to GameChannel with code: ${this.codeValue}`)
    if (this.codeValue) {
      this.subscription = createConsumer().subscriptions.create(
        { channel: 'GameChannel', code: this.codeValue },
        {
          connected: this._connected.bind(this),
          disconnected: this._disconnected.bind(this),
          received: this._received.bind(this)
        }
      )
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      console.log(`Disconnected from GameChannel with code: ${this.codeValue}`)
    }
  }

  _connected() {
    console.log(`Successfully connected to GameChannel with code: ${this.codeValue}`)
  }

  _disconnected() {
    console.log(`Disconnected from GameChannel with code: ${this.codeValue}`)
  }

  _received(data) {
    // Turbo Streams will handle most updates automatically.
    // This is for custom data handling if needed.
    console.log('Received data:', data)
  }
}
