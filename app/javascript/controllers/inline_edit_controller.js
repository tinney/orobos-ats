import { Controller } from "@hotwired/stimulus"

// Toggles between display text and inline edit form.
// Usage:
//   <div data-controller="inline-edit">
//     <span data-inline-edit-target="display">Text</span>
//     <form class="hidden" data-inline-edit-target="form">
//       <input data-inline-edit-target="input" />
//     </form>
//   </div>
export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    if (this.hasInputTarget) {
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
    // Reset input value to original display text
    if (this.hasInputTarget) {
      this.inputTarget.value = this.displayTarget.textContent.trim()
    }
  }
}
