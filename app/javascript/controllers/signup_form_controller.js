import { Controller } from "@hotwired/stimulus"

// Client-side validation for the tenant signup form.
// Validates all fields on submit, shows inline errors,
// and prevents submission until all fields are valid.
// Works alongside subdomain_validation_controller for
// real-time subdomain availability checking.
export default class extends Controller {
  static targets = ["companyName", "subdomain", "adminFirstName", "adminLastName", "adminEmail", "submitButton"]

  connect() {
    this.subdomainValid = false
    this.submitting = false
  }

  // Called on form submit — validates all fields and prevents
  // submission if any are invalid.
  validate(event) {
    this.clearAllErrors()

    const errors = []

    // Company name: required, min 2 chars
    const companyName = this.companyNameTarget.value.trim()
    if (companyName.length === 0) {
      this.showFieldError(this.companyNameTarget, "Company name is required")
      errors.push("company_name")
    } else if (companyName.length < 2) {
      this.showFieldError(this.companyNameTarget, "Company name must be at least 2 characters")
      errors.push("company_name")
    }

    // Subdomain: required, format validated
    const subdomain = this.subdomainTarget.value.trim().toLowerCase()
    if (subdomain.length === 0) {
      this.showFieldError(this.subdomainTarget, "Subdomain is required")
      errors.push("subdomain")
    } else if (subdomain.length < 3) {
      this.showFieldError(this.subdomainTarget, "Subdomain must be at least 3 characters")
      errors.push("subdomain")
    } else if (subdomain.length > 63) {
      this.showFieldError(this.subdomainTarget, "Subdomain must be 63 characters or fewer")
      errors.push("subdomain")
    } else if (!subdomain.match(/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/)) {
      this.showFieldError(this.subdomainTarget, "Only lowercase letters, numbers, and hyphens allowed")
      errors.push("subdomain")
    }

    // First name: required
    const firstName = this.adminFirstNameTarget.value.trim()
    if (firstName.length === 0) {
      this.showFieldError(this.adminFirstNameTarget, "First name is required")
      errors.push("first_name")
    }

    // Last name: required
    const lastName = this.adminLastNameTarget.value.trim()
    if (lastName.length === 0) {
      this.showFieldError(this.adminLastNameTarget, "Last name is required")
      errors.push("last_name")
    }

    // Email: required, format check
    const email = this.adminEmailTarget.value.trim()
    if (email.length === 0) {
      this.showFieldError(this.adminEmailTarget, "Email address is required")
      errors.push("email")
    } else if (!this.isValidEmail(email)) {
      this.showFieldError(this.adminEmailTarget, "Please enter a valid email address")
      errors.push("email")
    }

    if (errors.length > 0) {
      event.preventDefault()
      // Focus first invalid field
      const firstErrorField = this.getFieldTarget(errors[0])
      if (firstErrorField) firstErrorField.focus()
      return
    }

    // Prevent double submission
    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.disableSubmit()
  }

  // Clear error when user starts typing in a field
  clearFieldError(event) {
    const input = event.target
    this.removeFieldError(input)
    this.restoreInputStyle(input)
  }

  // --- Private helpers ---

  isValidEmail(email) {
    // Simple but effective email validation
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }

  showFieldError(input, message) {
    // Add error styling to input
    input.classList.remove(
      "border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500"
    )
    input.classList.add(
      "border-red-300", "text-red-900", "placeholder-red-300",
      "focus:border-red-500", "focus:ring-red-500"
    )

    // Insert error message below input (or below parent wrapper for subdomain)
    const errorEl = document.createElement("p")
    errorEl.className = "mt-1 text-sm text-red-600 signup-field-error"
    errorEl.setAttribute("role", "alert")
    errorEl.textContent = message

    // For subdomain, insert after the flex wrapper
    const insertAfter = input.closest(".flex.rounded-md") || input
    insertAfter.parentNode.insertBefore(errorEl, insertAfter.nextSibling)
  }

  removeFieldError(input) {
    const container = input.closest(".flex.rounded-md")?.parentNode || input.parentNode
    const errorEl = container.querySelector(".signup-field-error")
    if (errorEl) errorEl.remove()
  }

  restoreInputStyle(input) {
    input.classList.remove(
      "border-red-300", "text-red-900", "placeholder-red-300",
      "focus:border-red-500", "focus:ring-red-500"
    )
    input.classList.add(
      "border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500"
    )
  }

  clearAllErrors() {
    // Remove all error messages
    this.element.querySelectorAll(".signup-field-error").forEach(el => el.remove())

    // Restore all input styles
    const inputs = [
      this.companyNameTarget,
      this.subdomainTarget,
      this.adminFirstNameTarget,
      this.adminLastNameTarget,
      this.adminEmailTarget
    ]
    inputs.forEach(input => this.restoreInputStyle(input))
  }

  disableSubmit() {
    if (this.hasSubmitButtonTarget) {
      const btn = this.submitButtonTarget
      btn.disabled = true
      btn.dataset.originalText = btn.textContent
      btn.textContent = "Creating account…"
    }
  }

  getFieldTarget(errorKey) {
    switch (errorKey) {
      case "company_name": return this.companyNameTarget
      case "subdomain": return this.subdomainTarget
      case "first_name": return this.adminFirstNameTarget
      case "last_name": return this.adminLastNameTarget
      case "email": return this.adminEmailTarget
      default: return null
    }
  }
}
