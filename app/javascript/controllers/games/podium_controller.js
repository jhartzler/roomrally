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
    const hasBonk = entering.length > 0 && exiting.length > 0

    const PAIR_STAGGER = 200  // stagger between each enter/bonk pair
    const COLLISION_OFFSET = 300  // ms into rise when bonked player reacts

    // Pair entering players with exiting players for synchronized bonk collisions
    // First entering player bonks last exiting player (bottom of old podium)
    const exitReversed = [...exiting].reverse()

    if (hasBonk) {
      const pairCount = Math.min(entering.length, exitReversed.length)

      for (let i = 0; i < pairCount; i++) {
        const enterEl = this.element.querySelector(`[data-podium-player-id="${entering[i]}"]`)
        const exitEl = this.element.querySelector(`[data-podium-player-id="${exitReversed[i]}"]`)
        const pairDelay = i * PAIR_STAGGER

        // Entering player starts rising
        if (enterEl) {
          enterEl.style.animationDelay = `${pairDelay}ms`
          enterEl.classList.add("podium-enter")
        }

        // Bonked player reacts mid-rise — collision moment
        if (exitEl) {
          exitEl.style.animationDelay = `${pairDelay + COLLISION_OFFSET}ms`
          exitEl.classList.add("podium-bonked")
          exitEl.addEventListener("animationend", () => exitEl.remove(), { once: true })
        }
      }

      // Any remaining entering players without a bonk partner
      for (let i = pairCount; i < entering.length; i++) {
        const el = this.element.querySelector(`[data-podium-player-id="${entering[i]}"]`)
        if (!el) continue
        el.style.animationDelay = `${i * PAIR_STAGGER}ms`
        el.classList.add("podium-enter")
      }

      // Any remaining exiting players without an entering partner
      for (let i = pairCount; i < exitReversed.length; i++) {
        const el = this.element.querySelector(`[data-podium-player-id="${exitReversed[i]}"]`)
        if (!el) continue
        el.style.animationDelay = `${i * PAIR_STAGGER}ms`
        el.classList.add("podium-exit")
        el.addEventListener("animationend", () => el.remove(), { once: true })
      }
    } else {
      // No bonk — simple enter/exit
      entering.forEach((id, i) => {
        const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
        if (!el) return
        el.style.animationDelay = `${i * PAIR_STAGGER}ms`
        el.classList.add("podium-enter")
      })

      exiting.forEach((id, i) => {
        const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
        if (!el) return
        el.style.animationDelay = `${i * PAIR_STAGGER}ms`
        el.classList.add("podium-exit")
        el.addEventListener("animationend", () => el.remove(), { once: true })
      })
    }

    // Staying players settle
    current.forEach(id => {
      if (entering.includes(id)) return
      const el = this.element.querySelector(`[data-podium-player-id="${id}"]`)
      if (!el || !previousSet.has(id)) return
      el.classList.add("podium-stay")
    })
  }
}
