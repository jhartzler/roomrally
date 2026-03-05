import { Controller } from "@hotwired/stimulus"

// Recovers from missed Turbo Stream broadcasts by refreshing the page via
// Turbo.visit when stale state is detected. Two complementary strategies:
//
//   1. Visibility — tab hidden >5s then foregrounded (phone lock, tab switch)
//   2. Cable reconnect — WebSocket dropped and re-established (network hiccup)
//
export default class extends Controller {
  connect() {
    this.hiddenAt = null
    this.hadCableConnection = false
    this.refreshing = false

    this.boundVisibility = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.boundVisibility)

    this.cableObserver = new MutationObserver(this.handleCableMutation.bind(this))
    document.querySelectorAll("turbo-cable-stream-source").forEach(source => {
      this.cableObserver.observe(source, { attributes: true, attributeFilter: ["connected"] })
      if (source.hasAttribute("connected")) {
        this.hadCableConnection = true
      }
    })
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.boundVisibility)
    this.cableObserver?.disconnect()
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.hiddenAt = Date.now()
    } else if (this.hiddenAt && (Date.now() - this.hiddenAt) > 5_000) {
      this.hiddenAt = null
      this.refresh()
    } else {
      this.hiddenAt = null
    }
  }

  handleCableMutation(mutations) {
    for (const mutation of mutations) {
      const source = mutation.target
      if (source.hasAttribute("connected") && this.hadCableConnection) {
        this.refresh()
        return
      }
      if (source.hasAttribute("connected")) {
        this.hadCableConnection = true
      }
    }
  }

  refresh() {
    if (this.refreshing) return
    this.refreshing = true
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
