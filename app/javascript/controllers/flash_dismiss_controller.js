import { Controller } from "@hotwired/stimulus"

// Dismisses flash notification banners when the close button is clicked.
// Auto-dismisses success notices after 5 seconds.
//
// Usage:
//   <div data-controller="flash-dismiss">
//     <button data-action="click->flash-dismiss#dismiss">×</button>
//   </div>
export default class extends Controller {
  connect() {
    // Auto-dismiss success notices after 5 seconds
    if (this.element.classList.contains("bg-green-50")) {
      this.timeout = setTimeout(() => this.dismiss(), 5000)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity 200ms ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 200)
  }
}
