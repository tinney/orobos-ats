import { Controller } from "@hotwired/stimulus"

// Handles interactive role selection on the user form.
// Highlights the description matching the selected role and provides
// visual feedback when the role dropdown value changes.
export default class extends Controller {
  static targets = ["roleSelect", "roleDescription"]

  connect() {
    this.highlightSelected()
  }

  // Called when the role dropdown value changes
  roleChanged() {
    this.highlightSelected()
  }

  highlightSelected() {
    if (!this.hasRoleSelectTarget) return

    const selectedRole = this.roleSelectTarget.value

    this.roleDescriptionTargets.forEach((el) => {
      const role = el.dataset.role
      if (role === selectedRole) {
        el.classList.remove("opacity-50")
        el.classList.add("opacity-100", "bg-gray-50", "rounded", "px-2", "py-1", "-mx-2")
      } else {
        el.classList.add("opacity-50")
        el.classList.remove("opacity-100", "bg-gray-50", "rounded", "px-2", "py-1", "-mx-2")
      }
    })
  }
}
