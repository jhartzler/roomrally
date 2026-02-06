import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        end: String
    }
    static targets = ["output", "visual", "container"]

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
            console.warn("DramaticTimerController: Invalid End Time", this.endValue)
            this.stopTimer()
            this.outputTarget.textContent = "0s"
            return
        }

        const diff = endTime - now

        if (diff <= 0) {
            this.stopTimer()
            this.outputTarget.textContent = "0s"
            this.handleExpiration()
            return
        }

        const seconds = Math.ceil(diff / 1000)
        this.outputTarget.textContent = `${seconds}s`

        // Apply color zones and animations based on time remaining
        this.applyColorZone(seconds)
    }

    applyColorZone(seconds) {
        // Remove all color classes
        const colorClasses = [
            "text-blue-400", "text-yellow-400", "text-red-500",
            "bg-blue-950/40", "bg-yellow-950/40", "bg-red-950/40",
            "border-blue-400/30", "border-yellow-400/30", "border-red-400/30",
            "animate-timer-pulse"
        ]

        if (this.hasVisualTarget) {
            this.visualTarget.classList.remove(...colorClasses)
        }
        if (this.hasOutputTarget) {
            this.outputTarget.classList.remove(...colorClasses)
        }
        if (this.hasContainerTarget) {
            this.containerTarget.classList.remove(...colorClasses)
        }

        if (seconds > 30) {
            // Blue zone: 60-31 seconds (calm)
            if (this.hasVisualTarget) {
                this.visualTarget.classList.add("text-blue-400")
            }
            if (this.hasContainerTarget) {
                this.containerTarget.classList.add("bg-blue-950/40", "border-blue-400/30")
            }
        } else if (seconds > 10) {
            // Yellow zone: 30-11 seconds (warning)
            if (this.hasVisualTarget) {
                this.visualTarget.classList.add("text-yellow-400")
            }
            if (this.hasContainerTarget) {
                this.containerTarget.classList.add("bg-yellow-950/40", "border-yellow-400/30")
            }
        } else {
            // Red zone: 10-0 seconds (urgent)
            if (this.hasVisualTarget) {
                this.visualTarget.classList.add("text-red-500")
            }
            if (this.hasOutputTarget) {
                this.outputTarget.classList.add("animate-timer-pulse")
            }
            if (this.hasContainerTarget) {
                this.containerTarget.classList.add("bg-red-950/40", "border-red-400/30", "animate-timer-pulse")
            }
        }
    }

    handleExpiration() {
        // Flash the screen edge
        if (this.hasContainerTarget) {
            this.containerTarget.classList.add("animate-flash-edge")
        } else {
            // Flash the whole viewport if no container
            document.body.classList.add("animate-flash-edge")
            setTimeout(() => {
                document.body.classList.remove("animate-flash-edge")
            }, 1500)
        }

        // Final red state
        if (this.hasVisualTarget) {
            this.visualTarget.classList.add("text-red-500")
        }
        if (this.hasOutputTarget) {
            this.outputTarget.classList.add("text-red-500")
        }
    }
}
