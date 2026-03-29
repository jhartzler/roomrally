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
        this.#showFeedback(target, original, "clipboard")
      }).catch((err) => {
        console.warn("[clipboard] writeText failed, trying fallback:", err.message)
        this.#fallbackCopy(text, target, original)
      })
    } else {
      console.warn("[clipboard] navigator.clipboard unavailable, using fallback")
      this.#fallbackCopy(text, target, original)
    }
  }

  #showFeedback(target, original, method) {
    if (method) console.debug(`[clipboard] copied via ${method}`)
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
    const success = document.execCommand("copy")
    document.body.removeChild(textarea)

    if (success) {
      this.#showFeedback(target, original, "execCommand")
    } else {
      console.error("[clipboard] both writeText and execCommand failed")
      target.textContent = "Couldn't copy"
      setTimeout(() => { target.textContent = original }, 2000)
    }
  }
}
