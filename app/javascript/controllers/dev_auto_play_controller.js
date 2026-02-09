import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 },
    finished: { type: Boolean, default: false }
  }

  static targets = ["slider", "label", "startButton", "stopButton"]

  connect() {
    const params = new URLSearchParams(window.location.search)
    if (params.get("auto_play") === "true") {
      const interval = parseInt(params.get("interval") || "2000")
      this.intervalValue = interval
      if (this.hasSliderTarget) this.sliderTarget.value = interval
      this.updateLabel()

      if (!this.finishedValue) {
        this.showStopButton()
        this.timer = setTimeout(() => this.submitStep(), this.intervalValue)
      }
    }
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  start() {
    this.showStopButton()
    this.submitStep()
  }

  stop() {
    if (this.timer) clearTimeout(this.timer)
    this.showStartButton()
    // Reload without auto_play params
    const url = new URL(window.location.href)
    url.searchParams.delete("auto_play")
    url.searchParams.delete("interval")
    window.location.replace(url.toString())
  }

  updateInterval() {
    this.intervalValue = parseInt(this.sliderTarget.value)
    this.updateLabel()
  }

  updateLabel() {
    if (this.hasLabelTarget) {
      const seconds = (this.intervalValue / 1000).toFixed(1)
      this.labelTarget.textContent = `${seconds}s`
    }
  }

  submitStep() {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = `${this.urlValue}?auto_play=true&interval=${this.intervalValue}`

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "authenticity_token"
      input.value = csrfToken
      form.appendChild(input)
    }

    document.body.appendChild(form)
    form.submit()
  }

  showStopButton() {
    if (this.hasStartButtonTarget) this.startButtonTarget.classList.add("hidden")
    if (this.hasStopButtonTarget) this.stopButtonTarget.classList.remove("hidden")
  }

  showStartButton() {
    if (this.hasStartButtonTarget) this.startButtonTarget.classList.remove("hidden")
    if (this.hasStopButtonTarget) this.stopButtonTarget.classList.add("hidden")
  }
}
