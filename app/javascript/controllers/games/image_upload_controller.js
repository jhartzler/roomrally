import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "progress", "bar", "status"]

  compress(event) {
    const file = event.target.files[0]
    if (!file) return

    // iPhone HEIC and other unsupported formats silently fail canvas decode.
    // Skip client-side compression for anything that isn't a plain JPEG or PNG.
    const canCompress = /^image\/(jpeg|png)$/.test(file.type)
    if (!canCompress) {
      this.inputTarget.files = event.target.files
      const form = this.element.closest("form") || this.element
      setTimeout(() => {
        if (form.requestSubmit) {
          form.requestSubmit()
        } else {
          form.submit()
        }
      }, 0)
      return
    }

    this.progressTarget.classList.remove("hidden")
    this.labelTarget.textContent = "Compressing..."
    this.barTarget.style.width = "10%"

    const maxWidth = 1920
    const quality = 0.8

    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.onerror = () => {
        this.barTarget.style.width = "0%"
        this.statusTarget.textContent = "Upload failed: unsupported photo format."
        this.progressTarget.classList.add("hidden")
        this.labelTarget.textContent = "Replace Photo"
        const form = this.element.closest("form") || this.element
        setTimeout(() => {
          if (form.requestSubmit) {
            form.requestSubmit()
          } else {
            form.submit()
          }
        }, 0)
      }
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

          // Defer submission to the next tick so the browser has time to
          // register the mutated file input before Turbo serializes FormData.
          // Without this, some browsers (WebKit) may submit the old file or
          // an empty field because .files mutation is not instantly reflected
          // in the form's submit payload.
          setTimeout(() => {
            if (form.requestSubmit) {
              form.requestSubmit()
            } else {
              form.submit()
            }
          }, 0)

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
