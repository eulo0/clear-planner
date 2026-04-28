import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    const field = this.element.querySelector('input[name="q[field]"]')?.value || "name"
    this.set(field)
  }

  update(event) {
    const field = event?.detail?.value
    if (!this.hasInputTarget || !field) return

    this.set(field)
  }

  set(field) {
    if (!this.hasInputTarget) return
    if (field === "location") this.inputTarget.placeholder = "Search by location..."
    else if (field === "description") this.inputTarget.placeholder = "Search by description..."
    else this.inputTarget.placeholder = "Search by name..."
  }
}
