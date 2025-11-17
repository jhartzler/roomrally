// app/javascript/controllers/player_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { playerId: Number, hostId: Number }
  static targets = [ "actions" ]

  connect() {
    const currentPlayerIdSelector = document.querySelector("meta[name='current-player-id']")
    if (!currentPlayerIdSelector || !currentPlayerIdSelector.content) {
      this.actionsTarget.classList.add("hidden")
      return
    }

    const currentPlayerId = parseInt(currentPlayerIdSelector.content)
    const shouldShowActions = currentPlayerId === this.hostIdValue && this.playerIdValue !== currentPlayerId

    if (shouldShowActions) {
      this.actionsTarget.classList.remove("hidden")
    } else {
      this.actionsTarget.classList.add("hidden")
    }
  }
}
