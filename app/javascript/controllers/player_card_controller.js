// app/javascript/controllers/player_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { playerId: Number, hostId: Number }
  static targets = [ "actions" ]

  connect() {
    const currentPlayerId = parseInt(document.querySelector("meta[name='current-player-id']").content)
    if (currentPlayerId === this.hostIdValue && this.playerIdValue !== currentPlayerId) {
      this.actionsTarget.classList.remove("hidden")
    }
  }
}
