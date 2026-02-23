import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.hiddenAt = null
    this.boundHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.boundHandler)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.boundHandler)
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.hiddenAt = Date.now()
    } else if (this.hiddenAt && (Date.now() - this.hiddenAt) > 30_000) {
      this.hiddenAt = null
      Turbo.visit(window.location.href, { action: "replace" })
    } else {
      this.hiddenAt = null
    }
  }
}
