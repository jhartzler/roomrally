import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stageOnlySection"]

  connect() {
    this.updateStageOnlyVisibility()
  }

  updateStageOnlyVisibility() {
    if (!this.hasStageOnlySectionTarget) return

    const selected = this.element.querySelector("input[type=radio]:checked")
    const show = selected?.value === "Category List"
    this.stageOnlySectionTarget.hidden = !show
  }
}
