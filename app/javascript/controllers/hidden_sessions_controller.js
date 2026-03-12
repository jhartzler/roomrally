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
      this.applyFilter()
    }
  }

  unhideOne(event) {
    const code = event.currentTarget.dataset.roomCode
    const hidden = this.hiddenCodes().filter(c => c !== code)
    localStorage.setItem(this.keyValue, JSON.stringify(hidden))
    this.applyFilter()
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

      const btn = row.querySelector("[data-action*='hidden-sessions#']")
      if (btn) {
        if (isHidden && showHidden) {
          btn.textContent = "Unhide"
          btn.dataset.action = "click->hidden-sessions#unhideOne"
          btn.disabled = false
          btn.classList.add("text-gray-400")
          btn.classList.remove("text-gray-300")
        } else if (isHidden) {
          btn.textContent = "Hidden"
          btn.dataset.action = "click->hidden-sessions#hideOne"
          btn.disabled = true
          btn.classList.add("text-gray-400")
          btn.classList.remove("text-gray-300")
        } else {
          btn.innerHTML = "\u00d7"
          btn.dataset.action = "click->hidden-sessions#hideOne"
          btn.disabled = false
          btn.classList.remove("text-gray-400")
          btn.classList.add("text-gray-300")
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
