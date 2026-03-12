import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "row"]
  static values = { key: String }

  connect() {
    this.applyFilter()
  }

  toggle() {
    this.applyFilter()
  }

  hideOne(event) {
    const code = event.currentTarget.dataset.roomCode
    const hidden = this.hiddenCodes()
    if (!hidden.includes(code)) {
      hidden.push(code)
      localStorage.setItem(this.keyValue, JSON.stringify(hidden))
      event.currentTarget.textContent = "Hidden"
      event.currentTarget.disabled = true
      this.applyFilter()
    }
  }

  applyFilter() {
    if (!this.hasToggleTarget) return

    const showHidden = this.toggleTarget.checked
    const hidden = this.hiddenCodes()

    this.rowTargets.forEach(row => {
      const code = row.dataset.roomCode
      const isHidden = hidden.includes(code)

      if (isHidden && !showHidden) {
        row.classList.add("hidden")
      } else {
        row.classList.remove("hidden")
      }

      const btn = row.querySelector("[data-action*='hideOne']")
      if (btn) {
        if (isHidden) {
          btn.textContent = "Hidden"
          btn.disabled = true
          btn.classList.add("text-gray-400")
        } else {
          btn.innerHTML = "\u00d7"
          btn.disabled = false
          btn.classList.remove("text-gray-400")
        }
      }
    })
  }

  hiddenCodes() {
    try {
      return JSON.parse(localStorage.getItem(this.keyValue) || "[]")
    } catch {
      return []
    }
  }
}
