import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["packSelect", "settingsGroup"]

  gameTypeChanged(event) {
    const selectedType = event.target.value
    const packTypeMap = {
      "Write And Vote": "prompt_pack",
      "Speed Trivia": "trivia_pack",
      "Category List": "category_pack"
    }

    this.packSelectTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.packType !== packTypeMap[selectedType])
    })

    this.settingsGroupTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.gameType !== selectedType)
    })
  }
}
