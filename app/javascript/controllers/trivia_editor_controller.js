import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["questionList", "questionTemplate", "countDisplay", "questionField", "optionField", "correctAnswersContainer", "imagePreview", "imageInput", "existingImageContainer", "imageCountDisplay", "imageCountWarning", "positionField", "positionBadge", "optionRow", "optionLetter", "optionsContainer", "addOptionButton", "correctAnswerButtons", "collapseAllButton", "collapsibleContent"]
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
        const wrappers = Array.from(this.questionListTarget.querySelectorAll(".question-field-wrapper"))
            .filter(w => w.style.display !== "none")

        // Phase 1: Capture heights, build summaries, calculate collapsed sizes
        const cardData = wrappers.map(wrapper => {
            const expandedHeight = wrapper.offsetHeight
            const textarea = wrapper.querySelector("textarea[name*='[body]']")
            const questionText = textarea?.value?.trim() || "Untitled question"
            const badge = wrapper.querySelector("[data-trivia-editor-target='positionBadge']")
            const badgeText = badge?.textContent || "?"
            return { wrapper, expandedHeight, questionText, badgeText }
        })

        // Lock current heights and set up transitions
        cardData.forEach(({ wrapper, expandedHeight }) => {
            wrapper.dataset.expandedHeight = expandedHeight
            wrapper.style.height = expandedHeight + "px"
            wrapper.style.overflow = "hidden"
            wrapper.style.transition = "height 350ms ease-in-out"
        })

        // Phase 2: Insert summaries, hide content, animate to collapsed height
        requestAnimationFrame(() => {
            let collapsedHeights = []

            cardData.forEach(({ wrapper, questionText, badgeText }) => {
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

                const wrapperStyle = getComputedStyle(wrapper)
                const verticalPadding = parseFloat(wrapperStyle.paddingTop) + parseFloat(wrapperStyle.paddingBottom)
                const collapsedHeight = summary.offsetHeight + verticalPadding
                collapsedHeights.push(collapsedHeight)

                wrapper.style.height = collapsedHeight + "px"
            })

            // Reduce spacing between collapsed cards
            this.questionListTarget.classList.remove("space-y-6")
            this.questionListTarget.classList.add("space-y-1")

            // Calculate how far the dragged element will drift and scroll to compensate
            if (this.draggedElement) {
                const dragIndex = wrappers.indexOf(this.draggedElement)
                if (dragIndex > 0) {
                    // Sum up height reduction of all cards above the dragged one
                    // Each card: (expandedHeight - collapsedHeight) + spacing change (24px - 4px = 20px)
                    let totalDrift = 0
                    for (let i = 0; i < dragIndex; i++) {
                        totalDrift += cardData[i].expandedHeight - collapsedHeights[i] + 20
                    }
                    window.scrollBy(0, -totalDrift)
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

    insertQuestionBelow(event) {
        event.preventDefault()
        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return
        this.createQuestionField({ body: "", options: ["", "", "", ""], correct_answers: [] }, wrapper)
    }

    createQuestionField(data, afterWrapper = null) {
        const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000)
        const content = this.questionTemplateTarget.innerHTML.replace(
            /NEW_RECORD/g,
            timestamp
        )

        if (afterWrapper) {
            afterWrapper.insertAdjacentHTML('afterend', content)
        } else {
            this.questionListTarget.insertAdjacentHTML('beforeend', content)
        }

        const wrapper = afterWrapper ? afterWrapper.nextElementSibling : this.questionListTarget.lastElementChild

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

        // Initialize option add/remove state
        this.updateOptionState(wrapper)

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

    // --- Add / Remove Options ---

    addOption(event) {
        event.preventDefault()
        const wrapper = event.target.closest(".question-field-wrapper")
        const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
        const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
        if (rows.length >= 4) return

        // Clone the last existing option row — markup stays in ERB
        const row = rows[rows.length - 1].cloneNode(true)
        const input = row.querySelector("input[type='text']")
        input.value = ""

        // Insert before the "Add Option" button
        const addBtn = container.querySelector("[data-trivia-editor-target='addOptionButton']")
        container.insertBefore(row, addBtn)

        // Clone the last correct answer button too
        this.cloneCorrectAnswerButton(wrapper)

        this.updateOptionState(wrapper)
        this.syncCorrectAnswersFields(wrapper)

        // Focus the new input
        input.focus()
    }

    removeOption(event) {
        event.preventDefault()
        const wrapper = event.target.closest(".question-field-wrapper")
        const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
        const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
        if (rows.length <= 1) return

        const row = event.target.closest("[data-trivia-editor-target='optionRow']")
        const rowIndex = Array.from(rows).indexOf(row)
        row.remove()

        // Remove corresponding correct answer button
        this.removeCorrectAnswerButton(wrapper, rowIndex)

        // Re-letter remaining options and correct answer buttons
        this.updateOptionState(wrapper)
        this.syncCorrectAnswersFields(wrapper)
    }

    cloneCorrectAnswerButton(wrapper) {
        const container = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
        const labels = container.querySelectorAll("label")
        const clone = labels[labels.length - 1].cloneNode(true)
        clone.querySelector("input[type='checkbox']").checked = false
        container.appendChild(clone)
    }

    removeCorrectAnswerButton(wrapper, removedIndex) {
        const container = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
        const labels = container.querySelectorAll("label")
        if (labels[removedIndex]) {
            labels[removedIndex].remove()
        }
    }

    updateOptionState(wrapper) {
        const container = wrapper.querySelector("[data-trivia-editor-target='optionsContainer']")
        const rows = container.querySelectorAll("[data-trivia-editor-target='optionRow']")
        const addBtn = container.querySelector("[data-trivia-editor-target='addOptionButton']")

        // Re-letter option rows
        rows.forEach((row, i) => {
            const letter = String.fromCharCode(65 + i)
            const letterEl = row.querySelector("[data-trivia-editor-target='optionLetter']")
            if (letterEl) letterEl.textContent = letter

            const input = row.querySelector("input[type='text']")
            if (input) input.placeholder = `Option ${letter}`

            // Disable remove button if only 1 option remains
            const removeBtn = row.querySelector("[data-action='trivia-editor#removeOption']")
            if (removeBtn) {
                removeBtn.disabled = rows.length <= 1
                removeBtn.classList.toggle("opacity-10", rows.length <= 1)
                removeBtn.classList.toggle("pointer-events-none", rows.length <= 1)
            }
        })

        // Show/hide add button
        if (addBtn) {
            addBtn.classList.toggle("hidden", rows.length >= 4)
        }

        // Re-letter and re-index correct answer buttons
        const correctContainer = wrapper.querySelector("[data-trivia-editor-target='correctAnswerButtons']")
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

    // --- Collapse / Expand ---

    toggleCollapse(event) {
        const wrapper = event.target.closest(".question-field-wrapper")
        if (!wrapper) return
        const content = wrapper.querySelector("[data-trivia-editor-target='collapsibleContent']")
        if (!content) return

        const isCollapsed = content.classList.contains("hidden")
        content.classList.toggle("hidden", !isCollapsed)

        const icon = wrapper.querySelector(".collapse-icon")
        if (icon) icon.style.transform = isCollapsed ? "" : "rotate(-90deg)"

        this.updateCollapseAllButton()
    }

    collapseAll() {
        document.body.style.minHeight = document.body.scrollHeight + "px"
        this.collapsibleContentTargets.forEach(content => {
            const wrapper = content.closest(".question-field-wrapper")
            if (wrapper && wrapper.style.display !== "none") {
                content.classList.add("hidden")
                const icon = wrapper.querySelector(".collapse-icon")
                if (icon) icon.style.transform = "rotate(-90deg)"
            }
        })
        this.updateCollapseAllButton()
    }

    expandAll() {
        document.body.style.minHeight = ""
        this.collapsibleContentTargets.forEach(content => {
            const wrapper = content.closest(".question-field-wrapper")
            if (wrapper && wrapper.style.display !== "none") {
                content.classList.remove("hidden")
                const icon = wrapper.querySelector(".collapse-icon")
                if (icon) icon.style.transform = ""
            }
        })
        this.updateCollapseAllButton()
    }

    toggleCollapseAll() {
        const hasExpanded = this.collapsibleContentTargets.some(content => {
            const wrapper = content.closest(".question-field-wrapper")
            return wrapper && wrapper.style.display !== "none" && !content.classList.contains("hidden")
        })
        hasExpanded ? this.collapseAll() : this.expandAll()
    }

    updateCollapseAllButton() {
        if (!this.hasCollapseAllButtonTarget) return
        const hasExpanded = this.collapsibleContentTargets.some(content => {
            const wrapper = content.closest(".question-field-wrapper")
            return wrapper && wrapper.style.display !== "none" && !content.classList.contains("hidden")
        })
        this.collapseAllButtonTarget.textContent = hasExpanded ? "Collapse All" : "Expand All"
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
