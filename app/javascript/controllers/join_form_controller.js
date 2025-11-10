import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  join(event) {
    event.preventDefault()
    const roomCode = this.inputTarget.value.trim().toUpperCase()
    if (roomCode) {
      window.location.href = `/rooms/${roomCode}/join`
    }
  }
}