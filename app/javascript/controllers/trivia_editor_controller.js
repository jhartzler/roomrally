import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswerField"]
    static values = { ratio: { type: Number, default: 1 } }

    connect() {
        this.updateCount()
    }

    addQuestion(event) {
        if (event) event.preventDefault()
        this.createQuestionField({ body: "", options: ["", "", "", ""], correct_answer: "" })
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

        // Set correct answer
        const correctAnswerField = wrapper.querySelector("input[name*='[correct_answer]']")
        if (correctAnswerField && data.correct_answer) {
            correctAnswerField.value = data.correct_answer

            // Select the correct radio button
            const correctIndex = data.options?.indexOf(data.correct_answer) ?? 0
            const radioButtons = wrapper.querySelectorAll("input[name*='[correct_answer_index]']")
            if (radioButtons[correctIndex]) {
                radioButtons[correctIndex].checked = true
            }
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

    updateCorrectAnswer(event) {
        const radio = event.target
        const questionWrapper = radio.closest(".question-field-wrapper")
        const optionIndex = parseInt(radio.value)

        // Get the option fields for this question
        const optionFields = questionWrapper.querySelectorAll("input[name*='[options]']")
        const correctAnswerField = questionWrapper.querySelector("input[name*='[correct_answer]']")

        if (optionFields[optionIndex] && correctAnswerField) {
            correctAnswerField.value = optionFields[optionIndex].value
        }
    }

    optionChanged(event) {
        const optionField = event.target
        const questionWrapper = optionField.closest(".question-field-wrapper")
        const optionIndex = parseInt(optionField.dataset.optionIndex)

        // Check if this option is currently selected as correct
        const radioButtons = questionWrapper.querySelectorAll("input[name*='[correct_answer_index]']")
        const selectedRadio = Array.from(radioButtons).find(radio => radio.checked)

        if (selectedRadio && parseInt(selectedRadio.value) === optionIndex) {
            // Update the correct answer hidden field
            const correctAnswerField = questionWrapper.querySelector("input[name*='[correct_answer]']")
            if (correctAnswerField) {
                correctAnswerField.value = optionField.value
            }
        }
    }

    updateCount() {
        // Count visible question fields that are not marked for destruction
        const visibleQuestions = this.questionFieldTargets.filter(field => {
            const wrapper = field.closest(".question-field-wrapper")
            const destroyInput = wrapper.querySelector("input[name*='_destroy']")

            return wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
        })

        const count = visibleQuestions.length

        // Use the ratio passed from the server
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
