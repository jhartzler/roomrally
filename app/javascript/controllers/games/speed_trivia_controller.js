import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="games--speed-trivia"
export default class extends Controller {
    static targets = ["option"]

    disableOptions(event) {
        // Prevent double-clicks
        const button = event.currentTarget
        if (button.disabled) {
            event.preventDefault()
            return
        }

        // Visually disable all options immediately (defer slightly to allow form submit)
        setTimeout(() => {
            this.optionTargets.forEach(btn => {
                btn.disabled = true
                btn.classList.add("opacity-50", "cursor-not-allowed")
                btn.classList.remove("hover:bg-gray-700/80", "hover:border-blue-400", "active:scale-95")
            })
        }, 0)
    }
}
