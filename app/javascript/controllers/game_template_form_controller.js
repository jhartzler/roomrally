import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["packSelect", "settingsGroup"]

  connect() {
    this.restoreFromSession()
  }

  gameTypeChanged(event) {
    const selectedType = event.target.value
    const packTypeMap = {
      "Write And Vote": "prompt_pack",
      "Speed Trivia": "trivia_pack",
      "Category List": "category_pack",
      "Poll Game": "poll_pack"
    }

    this.packSelectTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.packType !== packTypeMap[selectedType])
    })

    this.settingsGroupTargets.forEach(el => {
      el.classList.toggle("hidden", el.dataset.gameType !== selectedType)
    })
  }

  saveAndNavigate(event) {
    // Serialize form data to sessionStorage, then let the link navigate naturally
    const form = this.element.closest("form") || this.element.querySelector("form")
    if (!form) return

    const data = {}
    new FormData(form).forEach((value, key) => {
      // Store only non-file fields
      if (typeof value === "string") {
        data[key] = value
      }
    })

    sessionStorage.setItem(this.storageKey(), JSON.stringify(data))
    // Allow the link's natural navigation to proceed (no preventDefault)
  }

  restoreFromSession() {
    const urlParams = new URLSearchParams(window.location.search)
    const newPackId = urlParams.get("new_pack_id")
    const savedData = sessionStorage.getItem(this.storageKey())

    if (!savedData) return

    const data = JSON.parse(savedData)
    this.applyFormData(data)

    if (newPackId) {
      this.selectNewPack(newPackId)
      sessionStorage.removeItem(this.storageKey())
      // Clean the URL param without reloading
      const cleanUrl = window.location.pathname
      window.history.replaceState({}, "", cleanUrl)
    }
  }

  // --- Private helpers ---

  storageKey() {
    return `game_template_draft_${window.location.pathname}`
  }

  applyFormData(data) {
    const form = this.element.closest("form") || this.element.querySelector("form")
    if (!form) return

    Object.entries(data).forEach(([key, value]) => {
      // Handle radio buttons (game_type)
      const radio = form.querySelector(`input[type=radio][name="${key}"][value="${value}"]`)
      if (radio) {
        radio.checked = true
        radio.dispatchEvent(new Event("change", { bubbles: true }))
        return
      }

      // Handle checkboxes
      const checkbox = form.querySelector(`input[type=checkbox][name="${key}"]`)
      if (checkbox) {
        checkbox.checked = (value === "true" || value === "1")
        return
      }

      // Handle selects and text inputs
      const field = form.querySelector(`[name="${key}"]:not([type=radio]):not([type=checkbox])`)
      if (field) {
        field.value = value
      }
    })
  }

  selectNewPack(packId) {
    // Find the visible pack select and choose the new pack
    const visibleSelect = this.packSelectTargets
      .find(el => !el.classList.contains("hidden"))
      ?.querySelector("select")

    if (visibleSelect) {
      const option = Array.from(visibleSelect.options).find(o => o.value === packId)
      if (option) {
        visibleSelect.value = packId
      }
    }
  }
}
