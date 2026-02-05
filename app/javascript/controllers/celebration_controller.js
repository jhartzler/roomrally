import { Controller } from "@hotwired/stimulus"
import confetti from "../utils/confetti"

export default class extends Controller {
    static values = {
        type: { type: String, default: "confetti" }
    }

    connect() {
        if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
            return
        }
        this.celebrate()
    }

    celebrate() {
        switch (this.typeValue) {
            case "confetti":
                this.showConfetti()
                break
            case "checkmark":
                this.showCheckmark()
                break
            case "trophy":
                this.showTrophy()
                break
        }
    }

    showConfetti() {
        confetti({
            count: 80,
            zIndex: 9999,
            duration: 3500
        })
    }

    showCheckmark() {
        const checkmark = document.createElement("div")
        checkmark.className = "fixed inset-0 flex items-center justify-center z-[9999] pointer-events-none"
        checkmark.innerHTML = `
            <div class="bg-green-500 rounded-full p-6 shadow-2xl animate-bounce-in">
                <svg class="w-16 h-16 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
                </svg>
            </div>
        `

        document.body.appendChild(checkmark)

        setTimeout(() => {
            checkmark.remove()
        }, 1500)
    }

    showTrophy() {
        // Show trophy emoji with bounce animation
        const trophy = document.createElement("div")
        trophy.className = "fixed inset-0 flex items-center justify-center z-[9999] pointer-events-none"
        trophy.innerHTML = `
            <div class="text-9xl animate-bounce-in">
                🏆
            </div>
        `

        document.body.appendChild(trophy)

        // Also trigger confetti
        this.showConfetti()

        setTimeout(() => {
            trophy.remove()
        }, 2000)
    }
}
