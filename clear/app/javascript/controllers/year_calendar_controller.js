import { Controller } from "@hotwired/stimulus"

// Renders the hover/focus tooltip for a year-view day cell from its data- payload
// (data-yc-date + data-yc-items). Revealed on hover AND keyboard focus for a11y.
export default class extends Controller {
  static targets = ["tip"]

  show(event) {
    const cell = event.target.closest(".yr-day.has-ev")
    if (!cell || !this.hasTipTarget) return

    let items = []
    try { items = JSON.parse(cell.dataset.ycItems || "[]") } catch { items = [] }
    if (!items.length) return

    this.tipTarget.innerHTML = this.template(cell.dataset.ycDate || "", items)
    this.tipTarget.classList.add("is-shown")
    this.position(cell)
  }

  hide(event) {
    if (!this.hasTipTarget) return

    // Ignore pointer/focus moves that stay inside the same day cell (avoids flicker).
    const cell = event.target.closest(".yr-day.has-ev")
    if (cell && event.relatedTarget && cell.contains(event.relatedTarget)) return

    this.tipTarget.classList.remove("is-shown")
  }

  template(date, items) {
    const rows = items.slice(0, 6).map((item) => `
      <div class="yr-tip-row">
        <span class="yr-tip-dot" style="background:${this.escape(item.color)}"></span>
        <span class="yr-tip-title">${this.escape(item.title)}</span>
        <span class="yr-tip-kind">${this.escape(item.kind)}</span>
      </div>`).join("")

    const more = items.length > 6
      ? `<div class="yr-tip-row" style="color:#71717a">+${items.length - 6} more</div>`
      : ""

    return `<div class="yr-tip-date">${this.escape(date)}</div>${rows}${more}`
  }

  position(cell) {
    const rect = cell.getBoundingClientRect()
    const tip  = this.tipTarget.getBoundingClientRect()

    let left = rect.left + rect.width / 2 - tip.width / 2
    left = Math.max(10, Math.min(left, window.innerWidth - tip.width - 10))

    let top = rect.top - tip.height - 8
    if (top < 10) top = rect.bottom + 8

    this.tipTarget.style.left = `${left}px`
    this.tipTarget.style.top = `${top}px`
  }

  // Titles are user-supplied, so escape before inserting as HTML.
  escape(value) {
    return String(value ?? "").replace(/[&<>"]/g, (char) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[char]
    ))
  }
}
