import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    // Can be used on a <details> element or any element to toggle visibility

    close(event) {
        if (event) event.preventDefault()

        if (this.element.tagName === "DETAILS") {
            this.element.removeAttribute("open")
        } else {
            this.element.classList.add("hidden")
        }
    }

    toggle(event) {
        if (event) event.preventDefault()

        if (this.element.tagName === "DETAILS") {
            this.element.toggleAttribute("open")
        } else {
            this.element.classList.toggle("hidden")
        }
    }
}
