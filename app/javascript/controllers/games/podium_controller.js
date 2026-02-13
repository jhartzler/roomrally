import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    players: Array,    // current top-4 player IDs
    previous: Array    // previous top-4 player IDs (by position)
  }

  connect() {
    this.animatePodium()
  }

  animatePodium() {
    const current = this.playersValue
    const previous = this.previousValue || []

    const currentSet = new Set(current)
    const previousSet = new Set(previous)
    const entering = new Set(current.filter(id => !previousSet.has(id)))

    const PAIR_STAGGER = 300
    const COLLISION_OFFSET = 450
    let pairIndex = 0

    current.forEach((id, i) => {
      const slot = this.element.querySelector(`[data-podium-slot="${i}"]`)
      if (!slot) return

      const isEntering = entering.has(id)
      const prevOccupant = previous[i]
      const prevWasBonked = prevOccupant && !currentSet.has(prevOccupant)

      if (isEntering && prevWasBonked) {
        // Slot has ghost (old player) + entering (new player)
        const enterEl = slot.querySelector("[data-podium-role='entering']")
        const ghostEl = slot.querySelector("[data-podium-role='ghost']")

        const delay = pairIndex * PAIR_STAGGER

        if (enterEl) {
          enterEl.style.animationDelay = `${delay}ms`
          enterEl.classList.add("podium-enter")
        }

        if (ghostEl) {
          ghostEl.style.animationDelay = `${delay + COLLISION_OFFSET}ms`
          ghostEl.classList.add("podium-bonked")
          ghostEl.addEventListener("animationend", () => ghostEl.remove(), { once: true })
        }

        pairIndex++
      } else if (isEntering) {
        const el = slot.querySelector("[data-podium-role='card']")
        if (el) {
          el.style.animationDelay = `${pairIndex * PAIR_STAGGER}ms`
          el.classList.add("podium-enter")
          pairIndex++
        }
      } else if (previousSet.has(id)) {
        const el = slot.querySelector("[data-podium-role='card']")
        if (el) el.classList.add("podium-stay")
      }
    })
  }
}
