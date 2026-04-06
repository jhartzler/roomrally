import QuestionListEditorController from "controllers/question_list_editor_controller"

export default class extends QuestionListEditorController {
    static targets = [
        "questionList", "questionTemplate", "countDisplay",
        "questionField", "optionField", "correctAnswersContainer",
        "imagePreview", "imageInput", "existingImageContainer",
        "imageCountDisplay", "imageCountWarning",
        "positionField", "positionBadge",
        "optionRow", "optionLetter", "optionsContainer", "addOptionButton",
        "correctAnswerButtons", "collapseAllButton", "collapsibleContent"
    ]
    static values = { ratio: { type: Number, default: 1 }, imageLimit: { type: Number, default: 20 } }

    // --- Hooks ---

    onConnect() {
        this.updateImageCount()
    }

    onQuestionAdded(wrapper) {
        // Initialize option add/remove state and sync correct answer buttons
        this.updateOptionState(wrapper)
        this.syncCorrectAnswersFields(wrapper)
    }

    onOptionAdded(wrapper, index) {
        this.cloneCorrectAnswerButton(wrapper)
        this.updateOptionState(wrapper)
        this.syncCorrectAnswersFields(wrapper)
    }

    onOptionRemoved(wrapper, removedIndex) {
        this.removeCorrectAnswerButton(wrapper, removedIndex)
        this.updateOptionState(wrapper)
        this.syncCorrectAnswersFields(wrapper)
    }

    // Override removeQuestion to also update image count
    removeQuestion(event) {
        super.removeQuestion(event)
        this.updateImageCount()
    }

    // --- Correct Answers ---

    updateCorrectAnswers(event) {
        const questionWrapper = event.target.closest(".question-field-wrapper")
        this.syncCorrectAnswersFields(questionWrapper)
    }

    syncCorrectAnswersFields(questionWrapper) {
        const checkboxes = questionWrapper.querySelectorAll("input[name*='[correct_answer_indices]']")
        const optionFields = questionWrapper.querySelectorAll("input[name*='[options]']")

        // Find the correct answers container
        const container = this.wrapperQuery(questionWrapper, "correctAnswersContainer")
        if (!container) return

        // Clear existing hidden fields
        container.innerHTML = ""

        // Derive the base name from any existing field in the wrapper
        const anyField = questionWrapper.querySelector("textarea[name*='[body]']")
        if (!anyField) return
        const baseName = anyField.name.replace("[body]", "[correct_answers][]")

        // Add a hidden field for each checked option
        checkboxes.forEach((checkbox, index) => {
            if (checkbox.checked && optionFields[index] && optionFields[index].value) {
                const hidden = document.createElement("input")
                hidden.type = "hidden"
                hidden.name = baseName
                hidden.value = optionFields[index].value
                container.appendChild(hidden)
            }
        })
    }

    optionChanged(event) {
        const questionWrapper = event.target.closest(".question-field-wrapper")
        this.syncCorrectAnswersFields(questionWrapper)
    }

    // --- Correct Answer Button Management ---

    cloneCorrectAnswerButton(wrapper) {
        const container = this.wrapperQuery(wrapper, "correctAnswerButtons")
        const labels = container.querySelectorAll("label")
        const clone = labels[labels.length - 1].cloneNode(true)
        clone.querySelector("input[type='checkbox']").checked = false
        container.appendChild(clone)
    }

    removeCorrectAnswerButton(wrapper, removedIndex) {
        const container = this.wrapperQuery(wrapper, "correctAnswerButtons")
        const labels = container.querySelectorAll("label")
        if (labels[removedIndex]) {
            labels[removedIndex].remove()
        }
    }

    updateOptionState(wrapper) {
        const rows = this.wrapperQueryAll(wrapper, "optionRow")

        // Re-letter and re-index correct answer buttons
        const correctContainer = this.wrapperQuery(wrapper, "correctAnswerButtons")
        if (correctContainer) {
            const labels = correctContainer.querySelectorAll("label")
            labels.forEach((label, i) => {
                const letter = String.fromCharCode(65 + i)
                const checkbox = label.querySelector("input[type='checkbox']")
                if (checkbox) checkbox.value = i
                const div = label.querySelector("div")
                if (div) div.textContent = letter
            })
        }
    }

    // --- Image Management ---

    previewImage(event) {
        const file = event.target.files[0]
        if (!file) return

        const wrapper = event.target.closest(".question-field-wrapper")
        const preview = this.wrapperQuery(wrapper, "imagePreview")

        // Determine if this question already has an image (replacing doesn't add to the count)
        const existingContainer = this.wrapperQuery(wrapper, "existingImageContainer")
        const hasExisting = existingContainer && existingContainer.style.opacity !== "0.3"
        const hasNew = preview && !preview.classList.contains("hidden")
        const alreadyHasImage = hasExisting || hasNew

        if (!alreadyHasImage && this.currentImageCount >= 20) {
            event.target.value = ""
            if (this.hasImageCountWarningTarget) {
                this.imageCountWarningTarget.classList.remove("hidden")
            }
            return
        }

        if (!preview) return

        const reader = new FileReader()
        reader.onload = (e) => {
            preview.src = e.target.result
            preview.classList.remove("hidden")
            this.updateImageCount()
        }
        reader.readAsDataURL(file)
    }

    removeImage(event) {
        const wrapper = event.target.closest(".question-field-wrapper")
        const container = this.wrapperQuery(wrapper, "existingImageContainer")
        if (container) {
            container.style.opacity = event.target.checked ? "0.3" : "1"
            this.updateImageCount()
        }
    }

    get currentImageCount() {
        const wrappers = this.element.querySelectorAll(".question-field-wrapper")
        let count = 0
        wrappers.forEach(wrapper => {
            if (wrapper.style.display === "none") return
            const existingContainer = this.wrapperQuery(wrapper, "existingImageContainer")
            const preview = this.wrapperQuery(wrapper, "imagePreview")
            const hasExisting = existingContainer && existingContainer.style.opacity !== "0.3"
            const hasNew = preview && !preview.classList.contains("hidden")
            if (hasExisting || hasNew) count++
        })
        return count
    }

    updateImageCount() {
        const count = this.currentImageCount
        const limit = this.imageLimitValue

        if (this.hasImageCountDisplayTarget) {
            this.imageCountDisplayTarget.textContent = `${count} / ${limit} used`
            this.imageCountDisplayTarget.classList.toggle("text-amber-300", count >= limit)
            this.imageCountDisplayTarget.classList.toggle("text-blue-300", count < limit)
        }

        if (this.hasImageCountWarningTarget) {
            this.imageCountWarningTarget.classList.toggle("hidden", count < limit)
        }
    }
}
