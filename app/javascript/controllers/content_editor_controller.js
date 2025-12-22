import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["promptList", "promptTemplate", "countDisplay", "promptField", "bulkText", "bulkSection"]
    static values = { ratio: { type: Number, default: 1 } }

    connect() {
        this.updateCount()
    }

    addPrompt(event) {
        if (event) event.preventDefault()
        this.createPromptField("")
    }

    bulkAdd(event) {
        event.preventDefault()
        const text = this.bulkTextTarget.value
        if (!text.trim()) return

        const lines = text.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0)

        lines.forEach(line => {
            this.createPromptField(line)
        })

        this.bulkTextTarget.value = ""
        this.bulkSectionTarget.open = false
    }

    createPromptField(value) {
        const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000) // Ensure unique ID for bulk
        const content = this.promptTemplateTarget.innerHTML.replace(
            /NEW_RECORD/g,
            timestamp
        )

        this.promptListTarget.insertAdjacentHTML('beforeend', content)

        // Find the newly added textarea and set its value
        const newField = this.promptListTarget.lastElementChild.querySelector("textarea")
        if (newField) {
            newField.value = value
        }

        this.updateCount()
    }

    removePrompt(event) {
        event.preventDefault()

        const wrapper = event.target.closest(".prompt-field-wrapper")

        if (wrapper.dataset.newRecord === "true") {
            wrapper.remove()
        } else {
            wrapper.style.display = "none"
            wrapper.querySelector("input[name*='_destroy']").value = "1"
        }

        this.updateCount()
    }

    updateCount() {
        // Count visible prompt fields that are not marked for destruction
        const visiblePrompts = this.promptFieldTargets.filter(field => {
            const wrapper = field.closest(".prompt-field-wrapper")
            const destroyInput = wrapper.querySelector("input[name*='_destroy']")

            return wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
        })

        const count = visiblePrompts.length

        // Use the ratio passed from the server
        const playerCapacity = Math.floor(count / this.ratioValue)
        this.countDisplayTarget.textContent = playerCapacity

        if (playerCapacity > 20) {
            this.countDisplayTarget.classList.add("text-red-600")
            this.countDisplayTarget.classList.remove("text-slate-900")
        } else {
            this.countDisplayTarget.classList.remove("text-red-600")
            this.countDisplayTarget.classList.add("text-slate-900")
        }
    }
}
