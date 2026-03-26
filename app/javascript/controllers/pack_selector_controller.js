import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "pack"]

  connect() {
    this.update()
  }

  update() {
    const selected = this.selectTarget.value
    this.packTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.gameType !== selected)
    })
  }
}
