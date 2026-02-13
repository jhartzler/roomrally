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

    // Determine bonked players: those who exited because someone new entered
    const hasBonk = entering.length > 0 && exiting.length > 0
    const bonked = new Set()
    if (hasBonk) {
      exiting.forEach(id => bonked.add(id))
    }

    const STAGGER_MS = 150

    // Animate exiting/bonked players — bottom-ranked first (last in array = lowest rank)
    const exitReversed = [...exiting].reverse()
    exitReversed.forEach((id, i) => {
      const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
      if (!el) return

      const delay = i * STAGGER_MS
      const animClass = bonked.has(id) ? "podium-bonked" : "podium-exit"
      el.style.animationDelay = `${delay}ms`
      el.classList.add(animClass)

      el.addEventListener("animationend", () => {
        el.remove()
      }, { once: true })
    })

    // Stagger entering players — delay so they rise after the exit sequence starts
    const exitDuration = exitReversed.length * STAGGER_MS
    current.forEach((id, i) => {
      const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
      if (!el) return

      if (entering.includes(id)) {
        // Enter after exits have started, staggered by position
        const delay = exitDuration + (i * STAGGER_MS)
        el.style.animationDelay = `${delay}ms`
        el.classList.add("podium-enter")
      } else if (previousSet.has(id)) {
        el.classList.add("podium-stay")
      }
    })
  }
}
