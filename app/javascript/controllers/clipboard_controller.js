import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["button", "label"]

  copy() {
    navigator.clipboard.writeText(this.textValue)
    const target = this.hasLabelTarget ? this.labelTarget : this.buttonTarget
    const original = target.textContent
    target.textContent = "Copied!"
    setTimeout(() => { target.textContent = original }, 2000)
  }
}
