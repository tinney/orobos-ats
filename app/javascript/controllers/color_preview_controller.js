import { Controller } from "@hotwired/stimulus"

// Provides live color preview for the brand color picker.
// Syncs the native color input with a hex text field and updates
// preview elements (button, link, dot) in real time.
export default class extends Controller {
  static targets = ["picker", "hex", "sampleButton", "sampleLink", "sampleDot"]

  // Called when the color picker input changes
  update() {
    const color = this.pickerTarget.value
    this.hexTarget.value = color
    this.applyColor(color)
  }

  // Called when the hex text field changes
  updateFromHex() {
    let color = this.hexTarget.value.trim()

    // Auto-prepend # if missing
    if (color.length > 0 && !color.startsWith("#")) {
      color = "#" + color
    }

    // Only apply if it looks like a valid hex color
    if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
      this.pickerTarget.value = color
      this.applyColor(color)
    }
  }

  applyColor(color) {
    if (this.hasSampleButtonTarget) {
      this.sampleButtonTarget.style.backgroundColor = color
    }
    if (this.hasSampleLinkTarget) {
      this.sampleLinkTarget.style.color = color
    }
    if (this.hasSampleDotTarget) {
      this.sampleDotTarget.style.backgroundColor = color
    }
  }
}
