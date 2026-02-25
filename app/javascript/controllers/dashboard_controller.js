import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.showPanel("overview")
  }

  switch(event) {
    this.showPanel(event.currentTarget.dataset.panel)
  }

  showPanel(panelName) {
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.panel === panelName
      const activeClasses = (tab.dataset.activeClasses || "bg-white/15 text-white").split(" ")
      const inactiveClasses = (tab.dataset.inactiveClasses || "text-blue-300/70").split(" ")

      if (active) {
        tab.classList.add(...activeClasses)
        tab.classList.remove(...inactiveClasses)
      } else {
        tab.classList.remove(...activeClasses)
        tab.classList.add(...inactiveClasses)
      }
    })
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.panel !== panelName
    })
  }
}
