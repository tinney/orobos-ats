import { Controller } from "@hotwired/stimulus"

// Manages the scorecard template form's nested category fields:
// - Adding new category rows from a <template> element
// - Removing categories (marking persisted ones for destruction, removing new ones from DOM)
// - Reordering categories via drag-and-drop and updating sort_order hidden fields
export default class extends Controller {
  static targets = ["categoriesList", "categoryRow", "categoryTemplate", "sortOrder", "dragHandle", "destroyField"]

  connect() {
    this.nextIndex = Date.now()
    this.initDragAndDrop()
  }

  // Add a new category row by cloning the template
  addCategory() {
    const template = this.categoryTemplateTarget
    const content = template.content.cloneNode(true)
    const index = this.nextIndex++

    // Replace NEW_INDEX placeholder with a unique index
    content.querySelectorAll("input, select, textarea").forEach(input => {
      if (input.name) {
        input.name = input.name.replace(/NEW_INDEX/g, index)
      }
      if (input.id) {
        input.id = input.id.replace(/NEW_INDEX/g, index)
      }
    })

    this.categoriesListTarget.appendChild(content)
    this.updateSortOrders()

    // Focus the new name field
    const rows = this.categoryRowTargets
    const lastRow = rows[rows.length - 1]
    if (lastRow) {
      const nameInput = lastRow.querySelector("input[type='text']")
      if (nameInput) nameInput.focus()
    }
  }

  // Remove a new (unpersisted) category row from the DOM
  removeCategoryRow(event) {
    const row = event.target.closest("[data-scorecard-template-form-target='categoryRow']")
    if (row) {
      row.remove()
      this.updateSortOrders()
    }
  }

  // Mark a persisted category for destruction (hide the row)
  removeCategory(event) {
    const row = event.target.closest("[data-scorecard-template-form-target='categoryRow']")
    if (row) {
      const destroyField = row.querySelector("[data-scorecard-template-form-target='destroyField']")
      if (destroyField) {
        destroyField.value = "1"
      }
      row.style.display = "none"
      this.updateSortOrders()
    }
  }

  // Update sort_order values based on current DOM order
  updateSortOrders() {
    let order = 0
    this.categoryRowTargets.forEach(row => {
      if (row.style.display !== "none") {
        const sortField = row.querySelector("[data-scorecard-template-form-target='sortOrder']")
        if (sortField) {
          sortField.value = order
          order++
        }
      }
    })
  }

  // Initialize basic drag-and-drop reordering
  initDragAndDrop() {
    this.categoriesListTarget.addEventListener("dragstart", this.handleDragStart.bind(this))
    this.categoriesListTarget.addEventListener("dragover", this.handleDragOver.bind(this))
    this.categoriesListTarget.addEventListener("drop", this.handleDrop.bind(this))
    this.categoriesListTarget.addEventListener("dragend", this.handleDragEnd.bind(this))

    // Make category rows draggable
    this.categoryRowTargets.forEach(row => {
      row.setAttribute("draggable", "true")
    })
  }

  handleDragStart(event) {
    const row = event.target.closest("[data-scorecard-template-form-target='categoryRow']")
    if (!row) return
    this.draggedRow = row
    row.classList.add("opacity-50")
    event.dataTransfer.effectAllowed = "move"
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const row = event.target.closest("[data-scorecard-template-form-target='categoryRow']")
    if (!row || row === this.draggedRow) return

    const rect = row.getBoundingClientRect()
    const midY = rect.top + rect.height / 2

    if (event.clientY < midY) {
      row.parentNode.insertBefore(this.draggedRow, row)
    } else {
      row.parentNode.insertBefore(this.draggedRow, row.nextSibling)
    }
  }

  handleDrop(event) {
    event.preventDefault()
    this.updateSortOrders()
  }

  handleDragEnd() {
    if (this.draggedRow) {
      this.draggedRow.classList.remove("opacity-50")
      this.draggedRow = null
    }
    this.updateSortOrders()
  }

  // When new targets connect, ensure they are draggable
  categoryRowTargetConnected(element) {
    element.setAttribute("draggable", "true")
  }
}
