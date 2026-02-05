import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["textarea", "counter", "message", "submit"]
    static values = {
        max: { type: Number, default: 280 }
    }

    connect() {
        this.update()
    }

    update() {
        const length = this.textareaTarget.value.length
        const remaining = this.maxValue - length

        // Update counter display
        this.counterTarget.textContent = `${length}/${this.maxValue}`

        // Color-coded feedback
        this.counterTarget.classList.remove("text-green-400", "text-yellow-400", "text-red-500")

        if (length <= 210) {
            // Green zone: 0-210 characters
            this.counterTarget.classList.add("text-green-400")
            this.messageTarget.textContent = length > 0 ? "Great answer! 💪" : ""
        } else if (length <= 260) {
            // Yellow zone: 211-260 characters
            this.counterTarget.classList.add("text-yellow-400")
            this.messageTarget.textContent = "Almost there! ✨"
        } else if (length <= this.maxValue) {
            // Red zone: 261-280 characters
            this.counterTarget.classList.add("text-red-500")
            this.messageTarget.textContent = `${remaining} characters left!`
        } else {
            // Over limit: 281+ characters
            this.counterTarget.classList.add("text-red-500")
            this.messageTarget.textContent = `${Math.abs(remaining)} over limit! ❌`
        }

        // Disable submit button if over limit
        if (this.hasSubmitTarget) {
            this.submitTarget.disabled = length > this.maxValue

            if (length > this.maxValue) {
                this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
                this.submitTarget.classList.remove("hover:bg-orange-600", "active:scale-[0.95]")
            } else {
                this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
                this.submitTarget.classList.add("hover:bg-orange-600", "active:scale-[0.95]")
            }
        }
    }
}
