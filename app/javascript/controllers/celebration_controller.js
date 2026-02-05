import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        type: { type: String, default: "confetti" }
    }

    connect() {
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
        const colors = [
            "#60a5fa", "#34d399", "#fbbf24", "#f87171", "#a78bfa", "#fb923c"
        ]

        const container = document.createElement("div")
        container.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 9999;
        `

        // Create 80 confetti particles
        for (let i = 0; i < 80; i++) {
            const confetti = document.createElement("div")
            const color = colors[Math.floor(Math.random() * colors.length)]
            const left = Math.random() * 100
            const delay = Math.random() * 0.5
            const duration = 2 + Math.random() * 1

            confetti.style.cssText = `
                position: absolute;
                width: ${Math.random() * 10 + 5}px;
                height: ${Math.random() * 10 + 5}px;
                background: ${color};
                left: ${left}%;
                top: -10%;
                opacity: 1;
                animation: confetti-fall ${duration}s linear ${delay}s forwards;
            `

            container.appendChild(confetti)
        }

        document.body.appendChild(container)

        // Remove after animation completes
        setTimeout(() => {
            container.remove()
        }, 3500)
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
