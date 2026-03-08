import { Controller } from "@hotwired/stimulus"

// Shared time slot picker for interview scheduling.
// Provides datetime-local input with validation and formatted display.
//
// Usage:
//   <div data-controller="time-slot-picker"
//        data-time-slot-picker-current-value="2026-03-10T14:00">
//     <div data-time-slot-picker-target="display">...</div>
//     <form data-time-slot-picker-target="form" class="hidden">
//       <input type="datetime-local" data-time-slot-picker-target="input" />
//     </form>
//     <button data-action="click->time-slot-picker#toggle">Change</button>
//   </div>
export default class extends Controller {
  static targets = ["display", "form", "input", "toggleButton"]
  static values = {
    current: { type: String, default: "" },
    minDate: { type: String, default: "" }
  }

  connect() {
    // Set minimum date to now if not specified
    if (this.hasInputTarget && !this.minDateValue) {
      const now = new Date()
      // Format as YYYY-MM-DDTHH:MM for datetime-local input
      const offset = now.getTimezoneOffset()
      const local = new Date(now.getTime() - offset * 60000)
      this.inputTarget.min = local.toISOString().slice(0, 16)
    } else if (this.hasInputTarget && this.minDateValue) {
      this.inputTarget.min = this.minDateValue
    }

    // Pre-fill input if current value exists
    if (this.hasInputTarget && this.currentValue) {
      this.inputTarget.value = this.currentValue
    }
  }

  // Toggle between display and edit modes
  toggle() {
    if (this.hasFormTarget) {
      const isHidden = this.formTarget.classList.contains("hidden")
      this.formTarget.classList.toggle("hidden")

      if (this.hasDisplayTarget && this.currentValue) {
        // Keep display visible even when form shows — user can see current value
      }

      if (isHidden && this.hasInputTarget) {
        this.inputTarget.focus()
      }

      // Update button text
      if (this.hasToggleButtonTarget) {
        this.toggleButtonTarget.textContent = isHidden ? "Cancel" : (this.currentValue ? "Change Time" : "Set Time")
      }
    }
  }

  // Cancel editing and hide the form
  cancel() {
    if (this.hasFormTarget) {
      this.formTarget.classList.add("hidden")
      // Reset input to current value
      if (this.hasInputTarget) {
        this.inputTarget.value = this.currentValue || ""
      }
      if (this.hasToggleButtonTarget) {
        this.toggleButtonTarget.textContent = this.currentValue ? "Change Time" : "Set Time"
      }
    }
  }

  // Validate the datetime before form submission
  validate(event) {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value
    if (!value) {
      event.preventDefault()
      this.inputTarget.focus()
      return
    }

    const selectedDate = new Date(value)
    const now = new Date()

    if (selectedDate < now) {
      event.preventDefault()
      this.inputTarget.setCustomValidity("Please select a future date and time")
      this.inputTarget.reportValidity()
      return
    }

    this.inputTarget.setCustomValidity("")
  }
}
