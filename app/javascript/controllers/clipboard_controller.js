import { Controller } from "@hotwired/stimulus"

// Copies a URL or text to the clipboard when a button is clicked.
// Usage:
//   <div data-controller="clipboard" data-clipboard-text-value="https://...">
//     <input data-clipboard-target="source" readonly value="https://..." />
//     <button data-action="click->clipboard#copy" data-clipboard-target="button">Copy</button>
//   </div>
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { text: String }

  copy() {
    const text = this.hasTextValue ? this.textValue : this.sourceTarget.value

    navigator.clipboard.writeText(text).then(() => {
      this.showCopiedFeedback()
    }).catch(() => {
      // Fallback for older browsers
      this.sourceTarget.select()
      document.execCommand("copy")
      this.showCopiedFeedback()
    })
  }

  showCopiedFeedback() {
    if (!this.hasButtonTarget) return

    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied!"
    this.buttonTarget.classList.add("bg-green-100", "text-green-800", "border-green-300")

    setTimeout(() => {
      this.buttonTarget.textContent = originalText
      this.buttonTarget.classList.remove("bg-green-100", "text-green-800", "border-green-300")
    }, 2000)
  }
}
