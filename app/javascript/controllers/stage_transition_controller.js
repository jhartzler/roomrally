import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.currentPhaseId = this.#childId()
    this.#animateChild()
    this.observer = new MutationObserver(() => this.#handleMutation())
    this.observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #handleMutation() {
    const newId = this.#childId()
    if (newId && newId !== this.currentPhaseId) {
      this.currentPhaseId = newId
      this.#animateChild()
    }
  }

  #stageElement() {
    return this.element.querySelector("[id^='stage_']")
  }

  #childId() {
    return this.#stageElement()?.id
  }

  #animateChild() {
    const el = this.#stageElement()
    if (!el) return
    el.classList.remove("animate-fade-in")
    void el.offsetWidth // force reflow
    el.classList.add("animate-fade-in")
  }
}
