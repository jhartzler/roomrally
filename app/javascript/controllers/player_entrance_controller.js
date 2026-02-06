import { Controller } from "@hotwired/stimulus"
import confetti from "../utils/confetti"

export default class extends Controller {
    static values = {
        playerId: Number
    }

    connect() {
        // Detect if this is a Turbo Stream append (new player joining)
        // vs initial page load
        const isTurboStreamAppend = document.readyState === "complete"

        if (isTurboStreamAppend) {
            // New player joining - trigger animation immediately
            this.animateEntrance()
            this.checkMilestone()
        }
        // On initial page load, don't animate (players are already there)
    }

    animateEntrance() {
        if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
            // No animation for reduced motion preference
            return
        }

        this.element.style.opacity = "0"

        // Use requestAnimationFrame to ensure the opacity change is applied
        requestAnimationFrame(() => {
            this.element.style.opacity = "1"
            this.element.classList.add("animate-slide-in-right")
        })
    }

    checkMilestone() {
        const milestones = [3, 5, 8]

        // Count total players in the list
        const playerList = document.getElementById("stage_player_list")
        const totalPlayers = playerList ? playerList.children.length : 0

        if (milestones.includes(totalPlayers)) {
            this.celebrateMilestone(totalPlayers)
        }
    }

    celebrateMilestone(totalPlayers) {
        if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
            return
        }

        // Create a celebration overlay
        const celebration = document.createElement("div")
        celebration.className = "fixed inset-0 flex items-center justify-center z-[9999] pointer-events-none"
        celebration.innerHTML = `
            <div class="text-center animate-bounce-in">
                <div class="text-7xl mb-4">🎉</div>
                <div class="text-3xl font-black text-white drop-shadow-lg">
                    ${totalPlayers} Players!
                </div>
            </div>
        `

        document.body.appendChild(celebration)

        // Trigger confetti
        this.triggerConfetti()

        setTimeout(() => {
            celebration.remove()
        }, 2000)
    }

    triggerConfetti() {
        confetti({
            count: 60,
            zIndex: 9998,
            duration: 3500
        })
    }
}
