import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswersContainer", "imagePreview", "imageInput", "existingImageContainer", "imageCountDisplay", "imageCountWarning", "positionField", "positionBadge"]
    static values = { ratio: { type: Number, default: 1 }, imageLimit: { type: Number, default: 20 } }

    connect() {
        this.draggedElement = null
        this.dragFromHandle = false
        this.updatePositions()
        this.updateCount()
        this.updateImageCount()

        // Track mousedown on drag handles to distinguish handle drags from content drags
        this.element.addEventListener("mousedown", (e) => {
            this.dragFromHandle = !!e.target.closest(".drag-handle")
        })
    }

    // --- Drag and Drop ---

    dragStart(event) {
        // Only allow drags initiated from the grip handle
        if (!this.dragFromHandle) {
            event.preventDefault()
            return
        }

        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return

        this.draggedElement = wrapper

        // Create a compact drag image instead of the full card
        const textarea = wrapper.querySelector("textarea[name*='[body]']")
        const questionText = textarea?.value?.trim() || "Untitled question"
        const badge = wrapper.querySelector("[data-trivia-editor-target='positionBadge']")
        const badgeText = badge?.textContent || "?"

        const ghost = document.createElement("div")
        ghost.className = "flex items-center gap-2 py-2 px-3 bg-white/10 backdrop-blur-md rounded-xl border border-orange-500/50 text-sm text-white/90 shadow-lg"
        ghost.style.cssText = "position: fixed; top: -1000px; left: -1000px; width: 300px; z-index: -1;"
        ghost.innerHTML = `
            <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded-full shrink-0">${badgeText}</span>
            <span class="truncate">${this.escapeHtml(questionText)}</span>
        `
        document.body.appendChild(ghost)
        event.dataTransfer.setDragImage(ghost, 150, 18)
        // Clean up ghost element after browser captures it
        setTimeout(() => ghost.remove(), 0)

        // Required for Firefox
        event.dataTransfer.effectAllowed = "move"
        event.dataTransfer.setData("text/plain", "")

        // Pin page height so background gradient doesn't shift during collapse
        document.body.style.minHeight = document.body.scrollHeight + "px"

        // Collapse all cards to compact summaries
        setTimeout(() => this.collapseCards(), 0)
    }

    dragEnd(event) {
        const wrapper = event.target.closest(".question-field-wrapper")
        if (wrapper) wrapper.classList.remove("opacity-40")

        // Clean up all drop indicators and expand cards back
        this.questionListTarget.querySelectorAll(".question-field-wrapper").forEach(el => {
            el.classList.remove("border-t-2", "border-b-2", "!border-t-orange-500", "!border-b-orange-500")
        })
        this.expandCards()

        // Release pinned page height after expand animation
        setTimeout(() => { document.body.style.minHeight = "" }, 400)

        this.draggedElement = null
    }

    collapseCards() {
        const wrappers = this.questionListTarget.querySelectorAll(".question-field-wrapper")

        // Remember where the dragged element is on screen before collapse
        const draggedRect = this.draggedElement?.getBoundingClientRect()
        const draggedViewportY = draggedRect?.top ?? 0

        // Phase 1: Capture current heights and lock them
        wrappers.forEach(wrapper => {
            if (wrapper.style.display === "none") return
            wrapper.dataset.expandedHeight = wrapper.offsetHeight
            wrapper.style.height = wrapper.offsetHeight + "px"
            wrapper.style.overflow = "hidden"
            wrapper.style.transition = "height 350ms ease-in-out"
        })

        // Phase 2: Insert summaries, hide content, animate to collapsed height
        requestAnimationFrame(() => {
            wrappers.forEach(wrapper => {
                if (wrapper.style.display === "none") return

                const textarea = wrapper.querySelector("textarea[name*='[body]']")
                const questionText = textarea?.value?.trim() || "Untitled question"
                const badge = wrapper.querySelector("[data-trivia-editor-target='positionBadge']")
                const badgeText = badge?.textContent || "?"

                // Hide all child elements
                Array.from(wrapper.children).forEach(child => {
                    child.dataset.dragHidden = child.style.display || ""
                    child.style.display = "none"
                })

                // Insert compact summary
                const summary = document.createElement("div")
                summary.className = "drag-summary flex items-center gap-2 py-1"
                summary.innerHTML = `
                    <span class="inline-flex items-center justify-center w-6 h-6 bg-blue-500/20 text-blue-300 font-bold text-xs rounded-full shrink-0">${badgeText}</span>
                    <span class="text-sm text-white/70 truncate">${this.escapeHtml(questionText)}</span>
                `
                wrapper.appendChild(summary)

                // Animate to collapsed height (summary + wrapper's vertical padding)
                const wrapperStyle = getComputedStyle(wrapper)
                const verticalPadding = parseFloat(wrapperStyle.paddingTop) + parseFloat(wrapperStyle.paddingBottom)
                wrapper.style.height = (summary.offsetHeight + verticalPadding) + "px"
            })

            // Reduce spacing between collapsed cards
            this.questionListTarget.classList.remove("space-y-6")
            this.questionListTarget.classList.add("space-y-1")

            // Instantly scroll so the dragged element stays at its original viewport position
            if (this.draggedElement) {
                const newRect = this.draggedElement.getBoundingClientRect()
                const drift = newRect.top - draggedViewportY
                if (Math.abs(drift) > 10) {
                    window.scrollBy(0, drift)
                }
            }
        })
    }

    expandCards() {
        const wrappers = this.questionListTarget.querySelectorAll(".question-field-wrapper")

        // Restore normal spacing
        this.questionListTarget.classList.remove("space-y-1")
        this.questionListTarget.classList.add("space-y-6")

        wrappers.forEach(wrapper => {
            // Remove compact summary
            const summary = wrapper.querySelector(".drag-summary")
            if (summary) summary.remove()

            // Restore all child elements
            Array.from(wrapper.children).forEach(child => {
                if ("dragHidden" in child.dataset) {
                    child.style.display = child.dataset.dragHidden
                    delete child.dataset.dragHidden
                }
            })

            const cleanup = () => {
                wrapper.style.height = ""
                wrapper.style.overflow = ""
                wrapper.style.transition = ""
            }

            // Animate back to expanded height if we have one
            if (wrapper.dataset.expandedHeight) {
                wrapper.style.height = wrapper.dataset.expandedHeight + "px"
                delete wrapper.dataset.expandedHeight
                wrapper.addEventListener("transitionend", cleanup, { once: true })
                // Fallback if transitionend doesn't fire (e.g., no actual change)
                setTimeout(cleanup, 400)
            } else {
                cleanup()
            }
        })
    }

    escapeHtml(text) {
        const div = document.createElement("div")
        div.textContent = text
        return div.innerHTML
    }

    dragOver(event) {
        event.preventDefault()
        event.dataTransfer.dropEffect = "move"

        // Auto-scroll when near viewport edges
        const scrollZone = 80
        const scrollSpeed = 8
        if (event.clientY < scrollZone) {
            window.scrollBy(0, -scrollSpeed)
        } else if (event.clientY > window.innerHeight - scrollZone) {
            window.scrollBy(0, scrollSpeed)
        }
    }

    dragEnter(event) {
        event.preventDefault()
        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper || wrapper === this.draggedElement) return

        // Clear all indicators first
        this.questionListTarget.querySelectorAll(".question-field-wrapper").forEach(el => {
            el.classList.remove("border-t-2", "border-b-2", "!border-t-orange-500", "!border-b-orange-500")
        })

        // Show indicator based on mouse position relative to element center
        const rect = wrapper.getBoundingClientRect()
        const midY = rect.top + rect.height / 2
        if (event.clientY < midY) {
            wrapper.classList.add("border-t-2", "!border-t-orange-500")
        } else {
            wrapper.classList.add("border-b-2", "!border-b-orange-500")
        }
    }

    dragLeave(event) {
        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return

        // Only remove if actually leaving the wrapper (not entering a child)
        const related = event.relatedTarget
        if (related && wrapper.contains(related)) return

        wrapper.classList.remove("border-t-2", "border-b-2", "!border-t-orange-500", "!border-b-orange-500")
    }

    drop(event) {
        event.preventDefault()
        const target = event.target.closest(".question-field-wrapper")
        if (!target || !this.draggedElement || target === this.draggedElement) return

        // Use the visible wrappers array to find the correct insertion point
        const visibleWrappers = this.visibleQuestionWrappers()
        const targetIndex = visibleWrappers.indexOf(target)

        const rect = target.getBoundingClientRect()
        const midY = rect.top + rect.height / 2

        if (event.clientY < midY) {
            target.parentNode.insertBefore(this.draggedElement, target)
        } else {
            // Insert after target: find the next wrapper and insert before it, or append
            const afterTarget = visibleWrappers[targetIndex + 1]
            if (afterTarget) {
                afterTarget.parentNode.insertBefore(this.draggedElement, afterTarget)
            } else {
                this.questionListTarget.appendChild(this.draggedElement)
            }
        }

        // Clean up indicators
        target.classList.remove("border-t-2", "border-b-2", "!border-t-orange-500", "!border-b-orange-500")

        this.updatePositions()
    }

    // --- Move Up / Down ---

    moveUp(event) {
        if (event.target.closest("button")?.disabled) return

        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return

        const visibleWrappers = this.visibleQuestionWrappers()
        const index = visibleWrappers.indexOf(wrapper)
        if (index <= 0) return

        const prev = visibleWrappers[index - 1]
        prev.parentNode.insertBefore(wrapper, prev)
        this.updatePositions()
        wrapper.scrollIntoView({ behavior: "smooth", block: "nearest" })
    }

    moveDown(event) {
        if (event.target.closest("button")?.disabled) return

        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return

        const visibleWrappers = this.visibleQuestionWrappers()
        const index = visibleWrappers.indexOf(wrapper)
        if (index < 0 || index >= visibleWrappers.length - 1) return

        const next = visibleWrappers[index + 1]
        next.parentNode.insertBefore(wrapper, next.nextSibling)
        this.updatePositions()
        wrapper.scrollIntoView({ behavior: "smooth", block: "nearest" })
    }

    visibleQuestionWrappers() {
        return Array.from(this.questionListTarget.querySelectorAll(".question-field-wrapper"))
            .filter(w => w.style.display !== "none")
    }

    // --- Position Management ---

    updatePositions() {
        const visibleWrappers = this.visibleQuestionWrappers()

        visibleWrappers.forEach((wrapper, i) => {
            const positionField = wrapper.querySelector("[data-trivia-editor-target='positionField']")
            const badge = wrapper.querySelector("[data-trivia-editor-target='positionBadge']")
            if (positionField) positionField.value = i + 1
            if (badge) badge.textContent = i + 1

            const upBtn = wrapper.querySelector("[data-action='trivia-editor#moveUp']")
            const downBtn = wrapper.querySelector("[data-action='trivia-editor#moveDown']")
            if (upBtn) {
                upBtn.disabled = i === 0
                upBtn.classList.toggle("opacity-10", i === 0)
            }
            if (downBtn) {
                downBtn.disabled = i === visibleWrappers.length - 1
                downBtn.classList.toggle("opacity-10", i === visibleWrappers.length - 1)
            }
        })
    }

    // --- Add / Remove Questions ---

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

        // Add to bottom instead of top
        this.questionListTarget.insertAdjacentHTML('beforeend', content)

        const wrapper = this.questionListTarget.lastElementChild

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

        this.updatePositions()
        this.updateCount()

        // Scroll new question into view
        wrapper.scrollIntoView({ behavior: "smooth", block: "nearest" })
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

        this.updatePositions()
        this.updateCount()
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

    // --- Image Management ---

    previewImage(event) {
        const file = event.target.files[0]
        if (!file) return

        const wrapper = event.target.closest(".question-field-wrapper")
        const preview = wrapper.querySelector("[data-trivia-editor-target='imagePreview']")

        // Determine if this question already has an image (replacing doesn't add to the count)
        const existingContainer = wrapper.querySelector("[data-trivia-editor-target='existingImageContainer']")
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
        const container = wrapper.querySelector("[data-trivia-editor-target='existingImageContainer']")
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
            const existingContainer = wrapper.querySelector("[data-trivia-editor-target='existingImageContainer']")
            const preview = wrapper.querySelector("[data-trivia-editor-target='imagePreview']")
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

    // --- Counts ---

    updateCount() {
        const visibleQuestions = this.questionFieldTargets.filter(field => {
            const wrapper = field.closest(".question-field-wrapper")
            const destroyInput = wrapper.querySelector("input[name*='_destroy']")

            return wrapper.style.display !== "none" && (!destroyInput || destroyInput.value !== "1")
        })

        if (!this.hasCountDisplayTarget) return

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
