import { Controller } from "@hotwired/stimulus"

// Handles dynamic behavior on the Role form:
// - Toggles location field placeholder/hint when "Remote" is checked
// - Validates salary min/max relationship
// - Tracks word count in Trix editor
// - Prevents submit when salary validation fails
export default class extends Controller {
  static targets = [
    "remoteCheckbox",
    "locationField",
    "salaryMin",
    "salaryMax",
    "salaryError",
    "trixEditor",
    "wordCount",
    "editorWrapper",
    "submitButton"
  ]

  connect() {
    this.toggleRemote()
    this.updateWordCount()
  }

  toggleRemote() {
    if (!this.hasRemoteCheckboxTarget || !this.hasLocationFieldTarget) return

    const isRemote = this.remoteCheckboxTarget.checked

    if (isRemote) {
      this.locationFieldTarget.placeholder = "Optional for remote roles"
      this.locationFieldTarget.classList.add("bg-gray-50")
    } else {
      this.locationFieldTarget.placeholder = "e.g. San Francisco, CA"
      this.locationFieldTarget.classList.remove("bg-gray-50")
    }
  }

  validateSalary() {
    if (!this.hasSalaryMinTarget || !this.hasSalaryMaxTarget || !this.hasSalaryErrorTarget) return

    const min = parseInt(this.salaryMinTarget.value, 10)
    const max = parseInt(this.salaryMaxTarget.value, 10)

    if (!isNaN(min) && !isNaN(max) && max < min) {
      this.salaryErrorTarget.classList.remove("hidden")
      this.salaryMaxTarget.classList.add("border-red-300", "text-red-900")
      this.salaryMaxTarget.classList.remove("border-gray-300")
    } else {
      this.salaryErrorTarget.classList.add("hidden")
      this.salaryMaxTarget.classList.remove("border-red-300", "text-red-900")
      this.salaryMaxTarget.classList.add("border-gray-300")
    }
  }

  updateWordCount() {
    if (!this.hasWordCountTarget) return

    // Get text content from the Trix editor
    let text = ""
    if (this.hasTrixEditorTarget) {
      const trixElement = this.trixEditorTarget.querySelector("trix-editor")
      if (trixElement && trixElement.editor) {
        text = trixElement.editor.getDocument().toString()
      }
    }

    const words = text.trim().split(/\s+/).filter(w => w.length > 0)
    const count = words.length
    if (count === 0) {
      this.wordCountTarget.textContent = ""
    } else {
      this.wordCountTarget.textContent = `${count} word${count !== 1 ? "s" : ""}`
    }
  }

  validateBeforeSubmit(event) {
    // Check salary validation
    if (this.hasSalaryMinTarget && this.hasSalaryMaxTarget) {
      const min = parseInt(this.salaryMinTarget.value, 10)
      const max = parseInt(this.salaryMaxTarget.value, 10)

      if (!isNaN(min) && !isNaN(max) && max < min) {
        event.preventDefault()
        this.validateSalary()
        this.salaryMinTarget.scrollIntoView({ behavior: "smooth", block: "center" })
        return
      }
    }

    // Disable submit button to prevent double-click
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.value = this.submitButtonTarget.value.replace(
        /^(Create|Update) Role$/,
        "Saving..."
      )
    }
  }
}
