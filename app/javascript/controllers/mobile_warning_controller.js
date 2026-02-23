import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { loggedIn: Boolean }

  connect() {
    this.dialogTarget.addEventListener("cancel", (e) => e.preventDefault())
    if (!this.loggedInValue && window.innerWidth <= 768) {
      this.dialogTarget.showModal()
    }
  }

  goToJoin() {
    window.location.href = "/play"
  }

  dismiss() {
    this.dialogTarget.close()
  }
}
