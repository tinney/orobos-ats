import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String }

  toggle() {
    const targetEl = document.getElementById(this.targetValue)
    if (targetEl) {
      targetEl.style.display = targetEl.style.display === "none" ? "block" : "none"
    }
  }
}
