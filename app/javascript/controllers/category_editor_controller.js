// app/javascript/controllers/category_editor_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categoryList", "categoryTemplate", "categoryField", "bulkText", "bulkSection"]

  addCategory(event) {
    event.preventDefault()
    this.createCategoryField("")
  }

  bulkAdd(event) {
    event.preventDefault()
    const text = this.bulkTextTarget.value
    if (!text.trim()) return

    const lines = text.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0)
    lines.forEach(line => this.createCategoryField(line))

    this.bulkTextTarget.value = ""
    this.bulkSectionTarget.open = false
  }

  createCategoryField(value) {
    const timestamp = new Date().getTime() + Math.floor(Math.random() * 1000)
    const content = this.categoryTemplateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)

    this.categoryListTarget.insertAdjacentHTML('afterbegin', content)

    const newField = this.categoryListTarget.firstElementChild.querySelector("input[type=text]")
    if (newField) {
      newField.value = value
    }
  }

  removeCategory(event) {
    event.preventDefault()
    const wrapper = event.target.closest(".category-field-wrapper")

    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove()
    } else {
      wrapper.style.display = "none"
      wrapper.querySelector("input[name*='_destroy']").value = "1"
    }
  }
}
