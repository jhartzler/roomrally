import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        duration: { type: Number, default: 3 }
    }
    static targets = ["number"]

    connect() {
        this.startCountdown()
    }

    startCountdown() {
        let count = this.durationValue

        // Show first number immediately
        this.showNumber(count)

        const interval = setInterval(() => {
            count--

            if (count > 0) {
                this.showNumber(count)
            } else {
                clearInterval(interval)
                this.fadeOut()
            }
        }, 1000)
    }

    showNumber(num) {
        // Update the number
        if (this.hasNumberTarget) {
            this.numberTarget.textContent = num
            // Trigger reflow to restart animation
            this.numberTarget.classList.remove("animate-countdown-scale")
            void this.numberTarget.offsetWidth
            this.numberTarget.classList.add("animate-countdown-scale")
        }
    }

    fadeOut() {
        // Fade out the entire overlay
        this.element.style.transition = "opacity 0.5s ease-out"
        this.element.style.opacity = "0"

        setTimeout(() => {
            this.element.remove()
        }, 500)
    }
}
