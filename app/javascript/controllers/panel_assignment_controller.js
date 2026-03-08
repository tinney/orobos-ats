import { Controller } from "@hotwired/stimulus"

// Manages panel interview assignments with add/remove interviewers.
// Filters the available interviewer dropdown to exclude already-assigned members.
//
// Usage:
//   <div data-controller="panel-assignment"
//        data-panel-assignment-assign-url-value="/admin/applications/:id/interview_phases/:id/interview/assign"
//        data-panel-assignment-assigned-value='["user-uuid-1","user-uuid-2"]'>
//     <select data-panel-assignment-target="userSelect">...</select>
//     <button data-action="click->panel-assignment#assign">Add</button>
//     <div data-panel-assignment-target="panel">...</div>
//   </div>
export default class extends Controller {
  static targets = ["userSelect", "panel", "emptyState", "assignButton"]
  static values = {
    assignUrl: String,
    assigned: { type: Array, default: [] }
  }

  connect() {
    this.filterOptions()
  }

  // Filter the dropdown to hide already-assigned users
  filterOptions() {
    if (!this.hasUserSelectTarget) return

    const assigned = this.assignedValue
    const options = this.userSelectTarget.querySelectorAll("option")

    options.forEach(option => {
      if (option.value === "") return // keep blank option
      option.hidden = assigned.includes(option.value)
      if (option.hidden && option.selected) {
        this.userSelectTarget.value = ""
      }
    })

    // Disable the add button if no users available to assign
    const availableOptions = Array.from(options).filter(o => o.value !== "" && !o.hidden)
    if (this.hasAssignButtonTarget) {
      this.assignButtonTarget.disabled = availableOptions.length === 0
    }

    // Update empty state visibility
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle("hidden", assigned.length > 0)
    }
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden", assigned.length === 0)
    }
  }

  // Validate selection before form submit
  validateSelection(event) {
    if (!this.hasUserSelectTarget || this.userSelectTarget.value === "") {
      event.preventDefault()
      this.userSelectTarget.focus()
    }
  }
}
