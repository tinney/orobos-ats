import { Controller } from "@hotwired/stimulus"

// Detects the user's browser timezone and submits it to the server
// if it differs from the stored timezone.
//
// Usage:
//   <div data-controller="timezone"
//        data-timezone-url-value="/admin/timezone"
//        data-timezone-current-value="UTC">
//   </div>
export default class extends Controller {
  static values = {
    url: String,
    current: String
  }

  connect() {
    const browserTimezone = this.detectTimezone()
    if (!browserTimezone) return

    // Only update if the detected timezone differs from what the server has
    if (browserTimezone !== this.currentValue) {
      this.updateTimezone(browserTimezone)
    }
  }

  detectTimezone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone
    } catch {
      return null
    }
  }

  updateTimezone(timezone) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken || !this.urlValue) return

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ time_zone: timezone })
    })
  }
}
