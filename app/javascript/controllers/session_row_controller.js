import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timeline", "arrow"]
  static values = { code: String }

  toggle(event) {
    // Don't toggle if clicking the room code link
    if (event.target.closest("a")) return

    this.timelineTarget.classList.toggle("hidden")
    this.arrowTarget.innerHTML = this.timelineTarget.classList.contains("hidden") ? "&#9656;" : "&#9662;"
  }

  navigate(event) {
    event.stopPropagation()
  }
}
