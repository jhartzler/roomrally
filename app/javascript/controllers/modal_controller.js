import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  closeBackground(event) {
    if (event.target === this.element) {
      this.element.remove()
    }
  }
}
