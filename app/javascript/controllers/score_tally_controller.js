import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    from: Number,
    to: Number
  }
  static targets = ["display"]

  connect() {
    if (this.fromValue === this.toValue) {
      this.displayTarget.textContent = this.toValue.toLocaleString()
      return
    }
    this.animate()
  }

  animate() {
    const from = this.fromValue
    const to = this.toValue
    const duration = 1500 // ms
    const startTime = performance.now()
    const display = this.displayTarget

    const tick = (now) => {
      const elapsed = now - startTime
      const t = Math.min(elapsed / duration, 1)
      // Cubic ease-out: starts fast, decelerates to final value
      const eased = 1 - Math.pow(1 - t, 3)
      const current = Math.round(from + (to - from) * eased)
      display.textContent = current.toLocaleString()

      if (t < 1) {
        requestAnimationFrame(tick)
      }
    }

    requestAnimationFrame(tick)
  }
}
