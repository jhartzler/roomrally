import { Controller } from "@hotwired/stimulus"

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
        const colors = ["#60a5fa", "#34d399", "#fbbf24", "#f87171", "#a78bfa", "#fb923c"]
        const container = document.createElement("div")
        container.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 9998;
        `

        for (let i = 0; i < 60; i++) {
            const confetti = document.createElement("div")
            const color = colors[Math.floor(Math.random() * colors.length)]
            const left = Math.random() * 100
            const delay = Math.random() * 0.3
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

        setTimeout(() => {
            container.remove()
        }, 3500)
    }
}
