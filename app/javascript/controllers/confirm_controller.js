import { Controller } from "@hotwired/stimulus"

// Intercepts form submission and shows a browser confirm dialog.
// Usage: <form data-controller="confirm" data-confirm-message-value="Are you sure?">
export default class extends Controller {
  static values = { message: { type: String, default: "Are you sure?" } }

  submit(event) {
    if (!window.confirm(this.messageValue)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}
