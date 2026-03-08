import { Controller } from "@hotwired/stimulus"

// Provides client-side filtering, sorting, and view toggling for the
// global candidates list. Works entirely on the DOM rows already
// rendered by the server — no fetch calls.
export default class extends Controller {
  static targets = ["row", "roleFilter", "statusFilter", "table", "grouped", "emptyMessage", "sortHeader"]
  static values = {
    view: { type: String, default: "flat" },    // "flat" or "grouped"
    sortColumn: { type: String, default: "" },
    sortDirection: { type: String, default: "asc" }
  }

  connect() {
    this.applyFilters()
  }

  // ── Filtering ──────────────────────────────────────────────────────

  filterByRole() {
    this.applyFilters()
  }

  filterByStatus() {
    this.applyFilters()
  }

  applyFilters() {
    const selectedRole = this.roleFilterTarget.value
    const selectedStatus = this.statusFilterTarget.value
    let visibleCount = 0

    this.rowTargets.forEach(row => {
      const roleMatch = !selectedRole || row.dataset.role === selectedRole
      const statusMatch = !selectedStatus || row.dataset.status === selectedStatus
      const visible = roleMatch && statusMatch

      row.style.display = visible ? "" : "none"
      if (visible) visibleCount++
    })

    this.emptyMessageTarget.style.display = visibleCount === 0 ? "" : "none"

    // Update grouped view visibility if in grouped mode
    if (this.viewValue === "grouped") {
      this.updateGroupedVisibility()
    }
  }

  // ── Sorting ────────────────────────────────────────────────────────

  sort(event) {
    const column = event.currentTarget.dataset.sortColumn
    if (!column) return

    // Toggle direction if same column, otherwise default asc
    if (this.sortColumnValue === column) {
      this.sortDirectionValue = this.sortDirectionValue === "asc" ? "desc" : "asc"
    } else {
      this.sortColumnValue = column
      this.sortDirectionValue = "asc"
    }

    this.performSort()
    this.updateSortIndicators()
  }

  performSort() {
    const column = this.sortColumnValue
    const direction = this.sortDirectionValue
    if (!column) return

    const tbody = this.tableTarget.querySelector("tbody")
    if (!tbody) return

    const rows = Array.from(this.rowTargets)

    rows.sort((a, b) => {
      let aVal = (a.dataset[column] || "").toLowerCase()
      let bVal = (b.dataset[column] || "").toLowerCase()

      // Handle date sorting
      if (column === "appliedAt") {
        aVal = new Date(a.dataset.appliedAt || 0).getTime()
        bVal = new Date(b.dataset.appliedAt || 0).getTime()
        return direction === "asc" ? aVal - bVal : bVal - aVal
      }

      // Handle numeric sorting (progress)
      if (column === "progress") {
        aVal = parseInt(a.dataset.progress || "0", 10)
        bVal = parseInt(b.dataset.progress || "0", 10)
        return direction === "asc" ? aVal - bVal : bVal - aVal
      }

      // String comparison
      if (aVal < bVal) return direction === "asc" ? -1 : 1
      if (aVal > bVal) return direction === "asc" ? 1 : -1
      return 0
    })

    rows.forEach(row => tbody.appendChild(row))
  }

  updateSortIndicators() {
    this.sortHeaderTargets.forEach(header => {
      const indicator = header.querySelector("[data-sort-indicator]")
      if (!indicator) return

      if (header.dataset.sortColumn === this.sortColumnValue) {
        indicator.textContent = this.sortDirectionValue === "asc" ? " ↑" : " ↓"
        header.classList.add("text-indigo-600")
        header.classList.remove("text-gray-500")
      } else {
        indicator.textContent = ""
        header.classList.remove("text-indigo-600")
        header.classList.add("text-gray-500")
      }
    })
  }

  // ── View Toggling ──────────────────────────────────────────────────

  showFlat() {
    this.viewValue = "flat"
    this.tableTarget.style.display = ""
    this.groupedTarget.style.display = "none"
    this.applyFilters()
  }

  showGrouped() {
    this.viewValue = "grouped"
    this.tableTarget.style.display = "none"
    this.groupedTarget.style.display = ""
    this.buildGroupedView()
  }

  buildGroupedView() {
    const selectedRole = this.roleFilterTarget.value
    const selectedStatus = this.statusFilterTarget.value

    // Group visible rows by role
    const groups = {}
    this.rowTargets.forEach(row => {
      const roleMatch = !selectedRole || row.dataset.role === selectedRole
      const statusMatch = !selectedStatus || row.dataset.status === selectedStatus
      if (!roleMatch || !statusMatch) return

      const roleTitle = row.dataset.roleTitle || "Unknown Role"
      if (!groups[roleTitle]) groups[roleTitle] = []
      groups[roleTitle].push(row)
    })

    const container = this.groupedTarget
    container.innerHTML = ""

    const roleNames = Object.keys(groups).sort()

    if (roleNames.length === 0) {
      container.innerHTML = '<p class="text-center text-gray-500 py-12">No candidates found matching the selected filters.</p>'
      return
    }

    roleNames.forEach(roleName => {
      const rows = groups[roleName]

      const section = document.createElement("div")
      section.className = "mb-6"

      const header = document.createElement("h3")
      header.className = "text-lg font-semibold text-gray-900 mb-2 flex items-center gap-2"
      header.innerHTML = `${this.escapeHtml(roleName)} <span class="text-sm font-normal text-gray-500">(${rows.length})</span>`
      section.appendChild(header)

      const table = document.createElement("table")
      table.className = "min-w-full divide-y divide-gray-200 bg-white rounded-lg border border-gray-200 overflow-hidden"

      const thead = document.createElement("thead")
      thead.className = "bg-gray-50"
      thead.innerHTML = `<tr>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Candidate</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Current Phase</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Progress</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Applied</th>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Flags</th>
      </tr>`
      table.appendChild(thead)

      const tbody = document.createElement("tbody")
      tbody.className = "bg-white divide-y divide-gray-200"

      rows.forEach(row => {
        // Clone the inner cells into a new row for the grouped table
        const clonedRow = row.cloneNode(true)
        clonedRow.style.display = ""
        tbody.appendChild(clonedRow)
      })

      table.appendChild(tbody)
      section.appendChild(table)
      container.appendChild(section)
    })
  }

  updateGroupedVisibility() {
    if (this.viewValue === "grouped") {
      this.buildGroupedView()
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
