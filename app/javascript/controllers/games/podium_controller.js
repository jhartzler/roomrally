import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    players: Array,    // current top-4 player IDs
    previous: Array    // previous top-4 player IDs
  }

  connect() {
    this.animatePodium()
  }

  animatePodium() {
    const current = this.playersValue
    const previous = this.previousValue || []

    const currentSet = new Set(current)
    const previousSet = new Set(previous)

    const entering = current.filter(id => !previousSet.has(id))
    const exiting = previous.filter(id => !currentSet.has(id))
    const staying = current.filter(id => previousSet.has(id))

    // Determine bonked players: those who exited because someone new entered
    const bonked = new Set()
    if (entering.length > 0 && exiting.length > 0) {
      exiting.forEach(id => bonked.add(id))
    }

    // Animate players currently on the podium
    current.forEach(id => {
      const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
      if (!el) return

      if (entering.includes(id)) {
        el.classList.add("podium-enter")
      } else if (staying.includes(id)) {
        el.classList.add("podium-stay")
      }
    })

    // Animate exiting players (rendered in DOM, animated out)
    exiting.forEach(id => {
      const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
      if (!el) return

      if (bonked.has(id)) {
        el.classList.add("podium-bonked")
      } else {
        el.classList.add("podium-exit")
      }

      // Remove element after animation completes
      el.addEventListener("animationend", () => {
        el.remove()
      }, { once: true })
    })
  }
}
