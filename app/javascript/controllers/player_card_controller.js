// app/javascript/controllers/player_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { playerId: Number, hostId: Number }
  static targets = [ "actions" ]

  connect() {
    const meta = document.querySelector("meta[name='current-player-id']")
    if (!meta || !meta.content) return

    const currentPlayerId = parseInt(meta.content)
    const isHost = currentPlayerId === this.hostIdValue
    const isSelf = this.playerIdValue === currentPlayerId

    if (isHost && !isSelf) {
      // Show actions on hover for the host viewing other players
      this.actionsTarget.classList.remove("hidden")
      this.actionsTarget.classList.add("flex")
    }
  }
}
