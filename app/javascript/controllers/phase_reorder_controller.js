import { Controller } from "@hotwired/stimulus"

// Provides drag-and-drop reordering for interview phases.
// On drop, submits a PATCH request to update the phase position.
// Falls back to up/down buttons for non-drag interactions.
//
// Usage:
//   <div data-controller="phase-reorder" data-phase-reorder-role-id-value="<role-id>">
//     <ul data-phase-reorder-target="list">
//       <li data-phase-reorder-target="item" data-phase-id="<phase-id>">
//         <span data-phase-reorder-target="handle">⠿</span>
//         ...
//       </li>
//     </ul>
//   </div>
export default class extends Controller {
  static targets = ["list", "item", "handle"]
  static values = { roleId: String }

  connect() {
    this.dragItem = null
    this.placeholder = null

    // Set up drag events on items
    this.itemTargets.forEach((item) => {
      item.setAttribute("draggable", "true")
      item.addEventListener("dragstart", this.handleDragStart.bind(this))
      item.addEventListener("dragend", this.handleDragEnd.bind(this))
      item.addEventListener("dragover", this.handleDragOver.bind(this))
      item.addEventListener("drop", this.handleDrop.bind(this))
    })
  }

  handleDragStart(event) {
    this.dragItem = event.currentTarget
    this.dragItem.classList.add("opacity-50")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", "")
  }

  handleDragEnd(event) {
    if (this.dragItem) {
      this.dragItem.classList.remove("opacity-50")
    }
    this.dragItem = null
    // Remove any drop indicators
    this.itemTargets.forEach((item) => {
      item.classList.remove("border-t-2", "border-blue-500")
    })
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    // Add visual indicator
    this.itemTargets.forEach((item) => {
      item.classList.remove("border-t-2", "border-blue-500")
    })
    if (event.currentTarget !== this.dragItem) {
      event.currentTarget.classList.add("border-t-2", "border-blue-500")
    }
  }

  handleDrop(event) {
    event.preventDefault()
    const dropTarget = event.currentTarget
    if (!this.dragItem || dropTarget === this.dragItem) return

    // Remove visual indicators
    this.itemTargets.forEach((item) => {
      item.classList.remove("border-t-2", "border-blue-500")
    })

    // Calculate new position
    const items = Array.from(this.listTarget.children)
    const newPosition = items.indexOf(dropTarget)
    const phaseId = this.dragItem.dataset.phaseId
    const roleId = this.roleIdValue

    // Move DOM element
    if (newPosition < items.indexOf(this.dragItem)) {
      this.listTarget.insertBefore(this.dragItem, dropTarget)
    } else {
      this.listTarget.insertBefore(this.dragItem, dropTarget.nextSibling)
    }

    // Submit move request
    this.submitMove(roleId, phaseId, newPosition)
  }

  submitMove(roleId, phaseId, newPosition) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const url = `/admin/roles/${roleId}/interview_phases/${phaseId}/move`

    const form = document.createElement("form")
    form.method = "POST"
    form.action = url
    form.style.display = "none"

    // CSRF token
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken || ""
    form.appendChild(csrfInput)

    // Method override for PATCH
    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = "patch"
    form.appendChild(methodInput)

    // Position parameter
    const positionInput = document.createElement("input")
    positionInput.type = "hidden"
    positionInput.name = "position"
    positionInput.value = newPosition
    form.appendChild(positionInput)

    document.body.appendChild(form)
    form.submit()
  }
}
