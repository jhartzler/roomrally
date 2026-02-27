import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stageOnlySection"]

  connect() {
    this.updateStageOnlyVisibility()
  }

  updateStageOnlyVisibility() {
    const selected = this.element.querySelector("input[name='room[game_type]']:checked")
    const show = selected?.value === "Category List"
    this.stageOnlySectionTarget.hidden = !show
  }
}
