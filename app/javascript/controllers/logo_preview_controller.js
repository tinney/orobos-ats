import { Controller } from "@hotwired/stimulus"

// Provides client-side image preview when a logo file is selected.
// Shows a thumbnail preview before the form is submitted.
export default class extends Controller {
  static targets = ["input", "previewContainer", "image"]

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) {
      this.previewContainerTarget.classList.add("hidden")
      return
    }

    // Only preview image files
    if (!file.type.startsWith("image/")) {
      this.previewContainerTarget.classList.add("hidden")
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.imageTarget.src = e.target.result
      this.previewContainerTarget.classList.remove("hidden")
    }
    reader.readAsDataURL(file)
  }
}
