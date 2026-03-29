import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["button", "label"]

  copy() {
    const text = this.textValue
    const target = this.hasLabelTarget ? this.labelTarget : this.buttonTarget
    const original = target.textContent

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        this.#showFeedback(target, original)
      }).catch(() => {
        this.#fallbackCopy(text, target, original)
      })
    } else {
      this.#fallbackCopy(text, target, original)
    }
  }

  #showFeedback(target, original) {
    target.textContent = "Copied!"
    setTimeout(() => { target.textContent = original }, 2000)
  }

  #fallbackCopy(text, target, original) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
    this.#showFeedback(target, original)
  }
}
