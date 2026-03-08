import { Controller } from "@hotwired/stimulus"

// Handles dynamic behavior on the Role form:
// - Toggles location field placeholder/hint when "Remote" is checked
// - Could be extended for salary validation, etc.
export default class extends Controller {
  static targets = ["remoteCheckbox", "locationField"]

  connect() {
    this.toggleRemote()
  }

  toggleRemote() {
    const isRemote = this.remoteCheckboxTarget.checked

    if (isRemote) {
      this.locationFieldTarget.placeholder = "Optional for remote roles"
      this.locationFieldTarget.classList.add("bg-gray-50")
    } else {
      this.locationFieldTarget.placeholder = "e.g. San Francisco, CA"
      this.locationFieldTarget.classList.remove("bg-gray-50")
    }
  }
}
