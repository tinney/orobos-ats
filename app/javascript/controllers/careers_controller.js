import { Controller } from "@hotwired/stimulus"

// Simple Stimulus controller for the careers page.
// Applies tenant brand color to interactive elements on connect.
export default class extends Controller {
  connect() {
    this.applyBrandColor()
  }

  applyBrandColor() {
    const brandColor = getComputedStyle(document.documentElement)
      .getPropertyValue("--brand-color")
      .trim()

    if (!brandColor) return

    // Apply brand color to all links within the careers page body
    this.element.querySelectorAll("a.brand-link").forEach((link) => {
      link.style.color = brandColor
    })
  }
}
