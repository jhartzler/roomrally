import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option"]

  disableOptions() {
    setTimeout(() => {
      this.optionTargets.forEach(btn => { btn.disabled = true })
    }, 0)
  }
}
