import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "image", "caption"]

  connect() {
    this.items = []
    this.currentIndex = 0
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    // Build items list from all image buttons in the panel
    const buttons = this.element.querySelectorAll("[data-games--image-viewer-src-param]")
    this.items = Array.from(buttons).map(btn => ({
      src: btn.dataset["games-ImageViewerSrcParam"],
      caption: btn.dataset["games-ImageViewerCaptionParam"]
    }))

    const clickedSrc = event.params.src
    this.currentIndex = this.items.findIndex(item => item.src === clickedSrc)
    if (this.currentIndex < 0) this.currentIndex = 0

    this.show()
  }

  close() {
    this.overlayTarget.classList.add("hidden")
  }

  next(event) {
    event.stopPropagation()
    if (this.items.length === 0) return
    this.currentIndex = (this.currentIndex + 1) % this.items.length
    this.show()
  }

  prev(event) {
    event.stopPropagation()
    if (this.items.length === 0) return
    this.currentIndex = (this.currentIndex - 1 + this.items.length) % this.items.length
    this.show()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  show() {
    const item = this.items[this.currentIndex]
    if (!item) return

    this.imageTarget.src = item.src
    this.captionTarget.textContent = item.caption
    this.overlayTarget.classList.remove("hidden")
  }
}
