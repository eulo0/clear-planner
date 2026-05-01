import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["reset"]

  connect() {
    this.update()
  }

  update() {
    if (!this.hasResetTarget) return

    const data = new FormData(this.element)
    const field = (data.get("q[field]") || "").toString()
    const hasActiveFilters =
      (data.get("q[term]") || "") !== "" ||
      (data.get("type") || "") !== "" ||
      (data.get("start_date") || "") !== "" ||
      (data.get("end_date") || "") !== "" ||
      (field !== "" && field !== "name")

    this.resetTarget.classList.toggle("hidden", !hasActiveFilters)
  }
}
