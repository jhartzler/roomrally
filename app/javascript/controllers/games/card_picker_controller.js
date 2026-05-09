import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["carousel"]

  // Horizontal scroll is handled by CSS overflow-x-auto.
  // This controller exists for future enhancements (swipe gestures, snap scrolling).
}
