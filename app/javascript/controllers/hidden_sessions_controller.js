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
      if (hidden.includes(code) && !showHidden) {
        row.classList.add("hidden")
      } else {
        row.classList.remove("hidden")
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
