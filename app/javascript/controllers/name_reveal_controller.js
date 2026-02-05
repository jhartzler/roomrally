import { Controller } from "@hotwired/stimulus"

// Blur effect with slow reveal for new player names on stage
export default class extends Controller {
  static values = { joinedAt: Number }
  static targets = ["name"]

  connect() {
    const joinedMs = this.joinedAtValue * 1000
    const timeSinceJoin = Date.now() - joinedMs

    // Only blur if just joined (< 5 seconds ago)
    if (timeSinceJoin < 5000) {
      this.startBlurred()
      // Reveal over 4 seconds after a brief delay
      setTimeout(() => this.reveal(), 1000)
    }
  }

  startBlurred() {
    // Start with heavy blur
    this.nameTarget.style.filter = 'blur(12px)'
    this.nameTarget.style.transition = 'none'
  }

  reveal() {
    // Smooth 4-second reveal
    this.nameTarget.style.transition = 'filter 4s ease-out'
    this.nameTarget.style.filter = 'blur(0px)'
  }
}
