import { Controller } from "@hotwired/stimulus"

// Controls a dropdown menu for role status transitions.
// Shows/hides a dropdown with available transitions and handles
// confirmation dialogs for destructive transitions (close, delete).
//
// Usage:
//   <div data-controller="role-transition">
//     <button data-action="click->role-transition#toggle">Status Actions</button>
//     <div data-role-transition-target="menu" class="hidden">...</div>
//   </div>
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._outsideClickHandler = this._handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.classList.contains("hidden")) {
      this._open()
    } else {
      this._close()
    }
  }

  close() {
    this._close()
  }

  // Intercepts form submission for destructive transitions requiring confirmation.
  // Attach to forms: data-action="submit->role-transition#confirmDestructive"
  // Set the message: data-role-transition-confirm-param="Are you sure?"
  confirmDestructive(event) {
    const message = event.params.confirm || "Are you sure you want to perform this action?"
    if (!window.confirm(message)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    } else {
      this._close()
    }
  }

  // Intercepts form submission for non-destructive transitions with simple confirmation.
  confirmTransition(event) {
    const message = event.params.confirm || "Are you sure?"
    if (!window.confirm(message)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    } else {
      this._close()
    }
  }

  _open() {
    this.menuTarget.classList.remove("hidden")
    // Defer adding the outside click handler to avoid immediate close
    requestAnimationFrame(() => {
      document.addEventListener("click", this._outsideClickHandler)
    })
  }

  _close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this._outsideClickHandler)
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._close()
    }
  }
}
