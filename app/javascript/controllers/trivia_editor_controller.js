import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswersContainer"]
    static values = { ratio: { type: Number, default: 1 } }

    connect() {
        this.updateCount()
    }

    addQuestion(event) {
        if (event) event.preventDefault()
        this.createQuestionField({ body: "", options: ["", "", "", ""], correct_answers: [] })
    }

    createQuestionField(data) {
        const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000)
        const content = this.questionTemplateTarget.innerHTML.replace(
            /NEW_RECORD/g,
            timestamp
        )

        this.questionListTarget.insertAdjacentHTML('afterbegin', content)

        const wrapper = this.questionListTarget.firstElementChild

        // Set question body
        const bodyField = wrapper.querySelector("textarea[name*='[body]']")
        if (bodyField && data.body) {
            bodyField.value = data.body
        }

        // Set options
        const optionFields = wrapper.querySelectorAll("input[name*='[options]']")
        if (data.options && Array.isArray(data.options)) {
            data.options.forEach((option, index) => {
                if (optionFields[index]) {
                    optionFields[index].value = option
                }
            })
        }

        // Set correct answers
        if (data.correct_answers && Array.isArray(data.correct_answers)) {
            const checkboxes = wrapper.querySelectorAll("input[name*='[correct_answer_indices]']")
            data.correct_answers.forEach(answer => {
                const correctIndex = data.options?.indexOf(answer) ?? -1
                if (correctIndex >= 0 && checkboxes[correctIndex]) {
                    checkboxes[correctIndex].checked = true
                }
            })
            this.syncCorrectAnswersFields(wrapper)
        }

        this.updateCount()
    }

    removeQuestion(event) {
        event.preventDefault()

        const wrapper = event.target.closest(".question-field-wrapper")

        if (wrapper.dataset.newRecord === "true") {
            wrapper.remove()
        } else {
            wrapper.style.display = "none"
            wrapper.querySelector("input[name*='_destroy']").value = "1"
        }

        this.updateCount()
    }

    updateCorrectAnswers(event) {
        const questionWrapper = event.target.closest(".question-field-wrapper")
        this.syncCorrectAnswersFields(questionWrapper)
    }

    syncCorrectAnswersFields(questionWrapper) {
        const checkboxes = questionWrapper.querySelectorAll("input[name*='[correct_answer_indices]']")
        const optionFields = questionWrapper.querySelectorAll("input[name*='[options]']")

        // Find the correct answers container
        const container = questionWrapper.querySelector("[data-trivia-editor-target='correctAnswersContainer']")
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

    updateCount() {
        const visibleQuestions = this.questionFieldTargets.filter(field => {
            const wrapper = field.closest(".question-field-wrapper")
            const destroyInput = wrapper.querySelector("input[name*='_destroy']")

            return wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
        })

        const count = visibleQuestions.length
        const playerCapacity = Math.floor(count / this.ratioValue)
        this.countDisplayTarget.textContent = playerCapacity

        if (playerCapacity > 20) {
            this.countDisplayTarget.classList.add("text-red-600")
            this.countDisplayTarget.classList.remove("text-white")
        } else {
            this.countDisplayTarget.classList.remove("text-red-600")
            this.countDisplayTarget.classList.add("text-white")
        }
    }
}
