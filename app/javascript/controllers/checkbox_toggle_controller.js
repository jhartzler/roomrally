import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "content"]

  connect() {
    this.toggle()
  }

  toggle() {
    const checked = this.checkboxTarget.checked
    this.contentTargets.forEach(el => {
      el.classList.toggle("hidden", !checked)
    })
  }
}
