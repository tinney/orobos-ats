import { Controller } from "@hotwired/stimulus"

// Manages promote/demote confirmation modals on the team management page.
// Shows a styled confirmation dialog before role change actions.
//
// Usage:
//   <div data-controller="role-change">
//     <button data-action="click->role-change#showModal"
//             data-role-change-url-param="/admin/users/1/promote"
//             data-role-change-name-param="Alice Admin"
//             data-role-change-action-param="promote"
//             data-role-change-target-role-param="Hiring Manager">
//       ↑ Promote
//     </button>
//     <!-- modal target is rendered once and reused -->
//   </div>
export default class extends Controller {
  static targets = ["modal", "modalTitle", "modalBody", "modalConfirmBtn", "hiddenForm"]

  showModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const { url, name, action, targetRole } = event.params

    // Set modal content
    const isPromote = action === "promote"
    const actionWord = isPromote ? "Promote" : "Demote"
    const actionPast = isPromote ? "promoted" : "demoted"

    this.modalTitleTarget.textContent = `${actionWord} ${name}?`
    this.modalBodyTarget.textContent =
      `${name} will be ${actionPast} to ${targetRole}. This changes their permissions immediately.`

    // Style confirm button based on action
    const btn = this.modalConfirmBtnTarget
    btn.textContent = `${actionWord} to ${targetRole}`
    btn.className = isPromote
      ? "inline-flex items-center px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
      : "inline-flex items-center px-4 py-2 bg-yellow-600 text-white text-sm font-medium rounded-md hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500"

    // Set the form action URL
    this.hiddenFormTarget.action = url

    // Show modal
    this.modalTarget.classList.remove("hidden")
    // Focus the cancel button for safety
    this.modalTarget.querySelector("[data-action='click->role-change#hideModal']").focus()
  }

  hideModal() {
    this.modalTarget.classList.add("hidden")
  }

  confirmAction() {
    // Disable confirm button to prevent double-clicks
    this.modalConfirmBtnTarget.disabled = true
    this.modalConfirmBtnTarget.textContent = "Processing…"
    this.modalConfirmBtnTarget.classList.add("opacity-50", "cursor-not-allowed")
    this.hiddenFormTarget.submit()
  }

  // Close on Escape key
  closeOnEscape(event) {
    if (event.key === "Escape" && !this.modalTarget.classList.contains("hidden")) {
      this.hideModal()
    }
  }

  // Close when clicking the backdrop
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.hideModal()
    }
  }
}
