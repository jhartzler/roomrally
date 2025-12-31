// app/javascript/controllers/player_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { playerId: Number, hostId: Number }
  static targets = ["actions"]

  connect() {
    const currentPlayerIdSelector = document.querySelector("meta[name='current-player-id']")
    if (!currentPlayerIdSelector || !currentPlayerIdSelector.content) {
      this.actionsTarget.classList.add("hidden")
      return
    }

    const currentPlayerId = parseInt(currentPlayerIdSelector.content)
    // hostIdValue defaults to 0 if empty/nil. We must ensure a valid host exists (ID > 0).
    const shouldShowActions = this.hostIdValue > 0 &&
      currentPlayerId === this.hostIdValue &&
      this.playerIdValue !== currentPlayerId

    if (shouldShowActions) {
      this.actionsTarget.classList.remove("hidden")
    } else {
      this.actionsTarget.classList.add("hidden")
    }
  }
}
