import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "progress", "bar", "status"]

  compress(event) {
    const file = event.target.files[0]
    if (!file) return

    this.progressTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Compressing..."
    this.barTarget.style.width = "10%"

    const maxWidth = 1920
    const quality = 0.8

    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement("canvas")
        let width = img.width
        let height = img.height

        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width)
          width = maxWidth
        }

        canvas.width = width
        canvas.height = height
        const ctx = canvas.getContext("2d")
        ctx.drawImage(img, 0, 0, width, height)

        this.barTarget.style.width = "50%"
        this.statusTarget.textContent = "Uploading..."

        canvas.toBlob((blob) => {
          const compressedFile = new File([blob], file.name, { type: "image/jpeg" })
          const dataTransfer = new DataTransfer()
          dataTransfer.items.add(compressedFile)
          this.inputTarget.files = dataTransfer.files

          this.barTarget.style.width = "70%"

          const form = this.element.closest("form") || this.element
          if (form.requestSubmit) {
            form.requestSubmit()
          } else {
            form.submit()
          }

          this.barTarget.style.width = "100%"
          this.statusTarget.textContent = "Done!"

          setTimeout(() => {
            this.progressTarget.classList.add("hidden")
            this.labelTarget.textContent = "Replace Photo"
            this.barTarget.style.width = "0%"
          }, 1500)
        }, "image/jpeg", quality)
      }
      img.src = e.target.result
    }
    reader.readAsDataURL(file)
  }
}
