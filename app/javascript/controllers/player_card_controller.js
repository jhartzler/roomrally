// app/javascript/controllers/player_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { playerId: Number, hostId: Number }
  static targets = [ "actions" ]

  connect() {
    const metaTag = document.querySelector("meta[name='current-player-id']")
    if (!metaTag || !metaTag.content) {
      return
    }

    const currentPlayerId = parseInt(metaTag.content)
    if (isNaN(currentPlayerId)) {
      return
    }

    if (currentPlayerId === this.hostIdValue && this.playerIdValue !== currentPlayerId) {
      this.actionsTarget.classList.remove("hidden")
      this.actionsTarget.classList.add("flex")
    }
  }
}
