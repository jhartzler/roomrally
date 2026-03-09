import { Controller } from "@hotwired/stimulus"

// Provides instant visual feedback on button/submit press before the form
// submits. Attached to a container (e.g. #hand_screen) and uses event
// delegation so it works with dynamically morphed content.
export default class extends Controller {
  connect() {
    this.pressed = null
    this.handleDown = this.onPointerDown.bind(this)
    this.handleUp = this.onPointerUp.bind(this)
    this.element.addEventListener("pointerdown", this.handleDown)
    this.element.addEventListener("pointerup", this.handleUp)
    this.element.addEventListener("pointerleave", this.handleUp, true)
    this.element.addEventListener("pointercancel", this.handleUp)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.handleDown)
    this.element.removeEventListener("pointerup", this.handleUp)
    this.element.removeEventListener("pointerleave", this.handleUp, true)
    this.element.removeEventListener("pointercancel", this.handleUp)
  }

  onPointerDown(event) {
    const button = event.target.closest("button, input[type='submit']")
    if (!button || button.disabled) return

    this.pressed = button
    button.style.transition = "transform 80ms ease, opacity 80ms ease"
    button.style.transform = "scale(0.97)"
    button.style.opacity = "0.85"
  }

  onPointerUp() {
    if (!this.pressed) return
    this.pressed.style.transform = ""
    this.pressed.style.opacity = ""
    this.pressed = null
  }
}
