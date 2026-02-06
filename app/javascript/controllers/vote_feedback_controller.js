import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["button"]

    vote(event) {
        // Create ripple effect
        const button = event.currentTarget
        const rect = button.getBoundingClientRect()
        const x = event.clientX - rect.left
        const y = event.clientY - rect.top

        const ripple = document.createElement("span")
        ripple.style.cssText = `
            position: absolute;
            width: 20px;
            height: 20px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.6);
            left: ${x}px;
            top: ${y}px;
            transform: translate(-50%, -50%);
            pointer-events: none;
        `
        ripple.classList.add("animate-ripple")

        // Ensure button has position relative
        button.style.position = "relative"
        button.style.overflow = "hidden"

        button.appendChild(ripple)

        // Remove ripple after animation
        setTimeout(() => {
            ripple.remove()
        }, 600)

        // Haptic feedback (mobile only)
        if (navigator.vibrate) {
            navigator.vibrate(50)
        }

        // Disable ALL vote buttons to prevent multiple votes
        const allVoteButtons = document.querySelectorAll('button[data-action*="vote-feedback#vote"]')
        allVoteButtons.forEach(btn => {
            btn.disabled = true
            btn.classList.add("opacity-75", "cursor-not-allowed")
        })

        // Show quick feedback message
        this.showFeedback(button)
    }

    showFeedback(button) {
        const feedback = document.createElement("div")
        feedback.className = "absolute inset-0 flex items-center justify-center bg-green-500/90 rounded-2xl animate-bounce-in"
        feedback.innerHTML = `
            <div class="flex items-center gap-2 text-white font-bold">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
                </svg>
                <span>Vote cast!</span>
            </div>
        `

        const container = button.closest(".response-card") || button.parentElement
        if (container) {
            container.style.position = "relative"
            container.appendChild(feedback)

            setTimeout(() => {
                feedback.remove()
            }, 1500)
        }
    }
}
