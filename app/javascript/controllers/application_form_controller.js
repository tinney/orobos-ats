import { Controller } from "@hotwired/stimulus"

// Handles the candidate application form:
// - Sets form_loaded_at timestamp for bot detection timing
// - Validates file uploads (type + size) before submission
// - Shows file info after selection
// - Manages submit button state (disable + loading text)
// - Provides client-side validation feedback
export default class extends Controller {
  static targets = ["timestamp", "submitButton", "fileInput", "fileInfo", "fileError", "form"]

  static values = {
    maxFileSize: { type: Number, default: 10485760 }, // 10MB in bytes
    allowedTypes: { type: Array, default: [
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ]},
    allowedExtensions: { type: Array, default: [".pdf", ".doc", ".docx"] }
  }

  connect() {
    // Set timestamp for bot detection timing
    if (this.hasTimestampTarget) {
      this.timestampTarget.value = new Date().toISOString()
    }

    this.submitting = false
  }

  // Called when file input changes
  validateFile(event) {
    const input = event.target
    const file = input.files[0]

    this.clearFileMessages()

    if (!file) return

    // Validate file type
    const validType = this.allowedTypesValue.includes(file.type)
    const extension = "." + file.name.split(".").pop().toLowerCase()
    const validExtension = this.allowedExtensionsValue.includes(extension)

    if (!validType && !validExtension) {
      this.showFileError("Please upload a PDF or Word document (.pdf, .doc, .docx)")
      input.value = ""
      return
    }

    // Validate file size
    if (file.size > this.maxFileSizeValue) {
      const maxMB = Math.round(this.maxFileSizeValue / 1048576)
      this.showFileError(`File is too large. Maximum size is ${maxMB}MB.`)
      input.value = ""
      return
    }

    // Show file info
    this.showFileInfo(file)
  }

  // Called on form submit
  submit(event) {
    // Prevent double submission
    if (this.submitting) {
      event.preventDefault()
      return
    }

    // Run client-side validation
    if (!this.validateRequired()) {
      event.preventDefault()
      return
    }

    // Check file if present
    if (this.hasFileInputTarget && this.fileInputTarget.files.length > 0) {
      const file = this.fileInputTarget.files[0]
      const validType = this.allowedTypesValue.includes(file.type)
      const extension = "." + file.name.split(".").pop().toLowerCase()
      const validExtension = this.allowedExtensionsValue.includes(extension)

      if ((!validType && !validExtension) || file.size > this.maxFileSizeValue) {
        event.preventDefault()
        return
      }
    }

    this.submitting = true
    this.disableSubmitButton()
  }

  // Remove selected file
  removeFile() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ""
    }
    this.clearFileMessages()
  }

  // Private helpers

  validateRequired() {
    if (!this.hasFormTarget) return true

    const requiredFields = this.formTarget.querySelectorAll("[required]")
    let valid = true

    requiredFields.forEach(field => {
      const wrapper = field.closest("[data-field-wrapper]")
      if (!field.value.trim()) {
        valid = false
        field.classList.add("border-red-500", "ring-red-500")
        field.classList.remove("border-gray-300")
        if (wrapper) {
          let errorEl = wrapper.querySelector("[data-field-error]")
          if (!errorEl) {
            errorEl = document.createElement("p")
            errorEl.setAttribute("data-field-error", "")
            errorEl.className = "mt-1 text-sm text-red-600"
            errorEl.textContent = "This field is required"
            wrapper.appendChild(errorEl)
          }
        }
      } else {
        field.classList.remove("border-red-500", "ring-red-500")
        field.classList.add("border-gray-300")
        if (wrapper) {
          const errorEl = wrapper.querySelector("[data-field-error]")
          if (errorEl) errorEl.remove()
        }
      }
    })

    if (!valid) {
      // Scroll to first error
      const firstError = this.formTarget.querySelector(".border-red-500")
      if (firstError) {
        firstError.scrollIntoView({ behavior: "smooth", block: "center" })
        firstError.focus()
      }
    }

    return valid
  }

  showFileInfo(file) {
    if (this.hasFileInfoTarget) {
      const sizeMB = (file.size / 1048576).toFixed(2)
      this.fileInfoTarget.innerHTML = `
        <div class="flex items-center gap-2 mt-2 p-3 bg-green-50 border border-green-200 rounded-md">
          <svg class="h-5 w-5 text-green-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-green-800 truncate">${this.escapeHtml(file.name)}</p>
            <p class="text-xs text-green-600">${sizeMB} MB</p>
          </div>
          <button type="button" data-action="application-form#removeFile" class="text-green-600 hover:text-green-800 text-sm font-medium">
            Remove
          </button>
        </div>
      `
      this.fileInfoTarget.classList.remove("hidden")
    }
  }

  showFileError(message) {
    if (this.hasFileErrorTarget) {
      this.fileErrorTarget.textContent = message
      this.fileErrorTarget.classList.remove("hidden")
    }
  }

  clearFileMessages() {
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.innerHTML = ""
      this.fileInfoTarget.classList.add("hidden")
    }
    if (this.hasFileErrorTarget) {
      this.fileErrorTarget.textContent = ""
      this.fileErrorTarget.classList.add("hidden")
    }
  }

  disableSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.dataset.originalText = this.submitButtonTarget.textContent
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline-block" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Submitting…
      `
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
