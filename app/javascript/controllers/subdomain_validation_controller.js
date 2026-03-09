import { Controller } from "@hotwired/stimulus"

// Real-time subdomain validation for the tenant signup form.
// Debounces input, validates format client-side, then checks
// availability via the server endpoint.
export default class extends Controller {
  static targets = ["input", "feedback", "submit", "preview"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  validate() {
    if (this.timeout) clearTimeout(this.timeout)

    const raw = this.inputTarget.value
    const subdomain = raw.trim().toLowerCase()

    // Update preview
    if (this.hasPreviewTarget) {
      this.previewTarget.textContent = subdomain || "yourcompany"
    }

    // Empty — reset state
    if (subdomain.length === 0) {
      this.setFeedback("neutral", "")
      this.setInputStyle("neutral")
      return
    }

    // Client-side format check
    if (!subdomain.match(/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/) || subdomain.length < 3) {
      if (subdomain.length < 3) {
        this.setFeedback("error", "Must be at least 3 characters")
      } else {
        this.setFeedback("error", "Only lowercase letters, numbers, and hyphens allowed. Must start and end with a letter or number.")
      }
      this.setInputStyle("error")
      return
    }

    if (subdomain.length > 63) {
      this.setFeedback("error", "Must be 63 characters or fewer")
      this.setInputStyle("error")
      return
    }

    // Show checking state
    this.setFeedback("checking", "Checking availability...")
    this.setInputStyle("neutral")

    // Debounce server check
    this.timeout = setTimeout(() => {
      this.checkAvailability(subdomain)
    }, 400)
  }

  async checkAvailability(subdomain) {
    try {
      const url = `${this.urlValue}?subdomain=${encodeURIComponent(subdomain)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        this.setFeedback("error", "Unable to check availability")
        this.setInputStyle("error")
        return
      }

      const data = await response.json()

      // Only update if subdomain hasn't changed while we were fetching
      if (this.inputTarget.value.trim().toLowerCase() !== subdomain) return

      if (data.available) {
        this.setFeedback("success", data.message)
        this.setInputStyle("success")
      } else {
        this.setFeedback("error", data.message)
        this.setInputStyle("error")
      }
    } catch {
      this.setFeedback("error", "Unable to check availability. Please try again.")
      this.setInputStyle("error")
    }
  }

  setFeedback(state, message) {
    if (!this.hasFeedbackTarget) return

    const el = this.feedbackTarget
    el.textContent = message

    // Reset classes
    el.className = "mt-1.5 text-sm flex items-center gap-1"

    switch (state) {
      case "success":
        el.classList.add("text-green-600")
        el.innerHTML = `<svg class="h-4 w-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg> ${this.escapeHtml(message)}`
        break
      case "error":
        el.classList.add("text-red-600")
        el.innerHTML = `<svg class="h-4 w-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg> ${this.escapeHtml(message)}`
        break
      case "checking":
        el.classList.add("text-gray-500")
        el.innerHTML = `<svg class="h-4 w-4 flex-shrink-0 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path></svg> ${this.escapeHtml(message)}`
        break
      default:
        el.textContent = ""
    }
  }

  setInputStyle(state) {
    const input = this.inputTarget

    // Remove previous state classes
    input.classList.remove(
      "border-red-300", "text-red-900", "focus:border-red-500", "focus:ring-red-500",
      "border-green-300", "text-green-900", "focus:border-green-500", "focus:ring-green-500",
      "border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500"
    )

    switch (state) {
      case "error":
        input.classList.add("border-red-300", "text-red-900", "focus:border-red-500", "focus:ring-red-500")
        break
      case "success":
        input.classList.add("border-green-300", "text-green-900", "focus:border-green-500", "focus:ring-green-500")
        break
      default:
        input.classList.add("border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500")
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
