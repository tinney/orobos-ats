import { Controller } from "@hotwired/stimulus"

// Prevents double-submission of forms by disabling the submit button
// and showing a spinner state after the first click.
export default class extends Controller {
  static targets = ["button"]

  disable() {
    if (this.hasButtonTarget) {
      const button = this.buttonTarget
      button.disabled = true
      button.dataset.originalText = button.textContent
      button.textContent = "Sending…"
    }
  }
}
