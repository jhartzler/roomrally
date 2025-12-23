import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        end: String
    }
    static targets = ["output", "visual"]

    connect() {
        this.startTimer()
    }

    disconnect() {
        this.stopTimer()
    }

    startTimer() {
        this.update()
        this.timer = setInterval(() => {
            this.update()
        }, 1000)
    }

    stopTimer() {
        if (this.timer) {
            clearInterval(this.timer)
        }
    }

    update() {
        const now = new Date().getTime()
        const endTime = new Date(this.endValue).getTime()

        if (isNaN(endTime)) {
            console.warn("TimerController: Invalid End Time", this.endValue)
            this.stopTimer()
            this.outputTarget.textContent = "0s"
            return
        }

        const diff = endTime - now

        if (diff <= 0) {
            this.stopTimer()
            this.outputTarget.textContent = "0s"
            if (this.hasVisualTarget) {
                this.visualTarget.classList.add("text-red-600", "animate-pulse")
            }
            return
        }

        const seconds = Math.ceil(diff / 1000)
        this.outputTarget.textContent = `${seconds}s`

        // Visual urgency
        if (this.hasVisualTarget) {
            if (seconds <= 10) {
                this.visualTarget.classList.add("text-red-500")
                this.visualTarget.classList.remove("text-indigo-600")
            } else {
                this.visualTarget.classList.add("text-indigo-600")
                this.visualTarget.classList.remove("text-red-500")
            }
        }
    }
}
