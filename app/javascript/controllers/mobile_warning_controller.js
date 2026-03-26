import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { loggedIn: Boolean }

  connect() {
    this.cancelHandler = (e) => e.preventDefault()
    this.dialogTarget.addEventListener("cancel", this.cancelHandler)
    if (!this.loggedInValue && window.innerWidth <= 768) {
      this.dialogTarget.showModal()
    }
  }

  disconnect() {
    this.dialogTarget.removeEventListener("cancel", this.cancelHandler)
  }

  goToJoin() {
    window.location.href = "/play"
  }

  dismiss() {
    this.dialogTarget.close()
  }
}
