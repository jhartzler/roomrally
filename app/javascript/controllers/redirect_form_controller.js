import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]
  static values = { urlTemplate: String }

  join(event) {
    event.preventDefault()
    // Sanitize the input to allow only alphanumeric characters
    const sanitizedValue = this.inputTarget.value.replace(/[^a-zA-Z0-9]/g, "").trim().toUpperCase()
    if (sanitizedValue) {
      const url = this.urlTemplateValue.replace("{{value}}", sanitizedValue)
      window.location.href = url
    }
  }
}