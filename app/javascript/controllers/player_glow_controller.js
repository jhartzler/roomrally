import { Controller } from "@hotwired/stimulus"

// Blue glow effect for newly joined players in backstage
export default class extends Controller {
  static values = { joinedAt: Number }

  connect() {
    const joinedMs = this.joinedAtValue * 1000
    const timeSinceJoin = Date.now() - joinedMs

    // Only glow if joined in last 3 seconds
    if (timeSinceJoin < 3000) {
      this.startGlow()
      setTimeout(() => this.fadeGlow(), 3000 - timeSinceJoin)
    }
  }

  startGlow() {
    // Blue glow effect matching Room Rally brand
    this.element.style.boxShadow = '0 0 20px rgba(96, 165, 250, 0.6)'
    this.element.style.borderColor = 'rgba(96, 165, 250, 0.8)'
    this.element.style.transition = 'none'
  }

  fadeGlow() {
    // Smooth 3-second fade to normal state
    this.element.style.transition = 'box-shadow 3s ease-out, border-color 3s ease-out'
    this.element.style.boxShadow = ''
    this.element.style.borderColor = ''
  }
}
