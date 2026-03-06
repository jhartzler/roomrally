import { Controller } from "@hotwired/stimulus"

// Recovers from missed Turbo Stream broadcasts by refreshing the page via
// Turbo.visit when stale state is detected. Two complementary strategies:
//
//   1. Visibility — tab hidden >5s then foregrounded (phone lock, tab switch)
//   2. Cable reconnect — WebSocket dropped and re-established (network hiccup)
//
// The page may have multiple turbo-cable-stream-source elements (e.g. one for
// the room, one for the player). Each source connects independently on page
// load. We track per-source state with a WeakSet so the second source
// connecting is NOT mistaken for a reconnection. A refresh only fires when a
// specific source that was previously connected gets the "connected" attribute
// again (i.e. it disconnected and reconnected).
//
export default class extends Controller {
  connect() {
    this.hiddenAt = null
    this.refreshing = false
    this.connectedSources = new WeakSet()

    this.boundVisibility = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.boundVisibility)

    this.cableObserver = new MutationObserver(this.handleCableMutation.bind(this))
    document.querySelectorAll("turbo-cable-stream-source").forEach(source => {
      this.cableObserver.observe(source, { attributes: true, attributeFilter: ["connected"] })
      if (source.hasAttribute("connected")) {
        this.connectedSources.add(source)
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
      if (source.hasAttribute("connected")) {
        if (this.connectedSources.has(source)) {
          // This specific source was already connected — it reconnected
          this.refresh()
          return
        }
        this.connectedSources.add(source)
      }
    }
  }

  refresh() {
    if (this.refreshing) return
    this.refreshing = true
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
