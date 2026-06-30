import { Controller } from "@hotwired/stimulus"

// Tabbed planner palette: switch between the Tasks palette and the Routine
// blocks palette via a segmented control (matching the analytics page tabs).
// The whole widget self-hides unless a day/week calendar grid is visible —
// month/year views have no visible day columns, so there's nothing to drag onto.
// The inner task-palette / block-palette controllers keep their own drag logic;
// this controller only governs which panel shows and whether the widget shows.
export default class extends Controller {
  static targets = ["widget", "tab", "panel"]
  static values = { active: { type: String, default: "tasks" } }

  connect() {
    this._render()
    this._syncVisibility()
    this._observer = new MutationObserver(() => this._syncVisibility())
    const cal = document.getElementById("dashboard_calendar")
    if (cal) {
      this._observer.observe(cal, {
        attributes: true,
        subtree: true,
        attributeFilter: ["class", "style", "hidden"],
      })
    }
  }

  disconnect() {
    this._observer?.disconnect()
  }

  select(event) {
    this.activeValue = event.currentTarget.dataset.tab
  }

  activeValueChanged() {
    this._render()
  }

  _render() {
    this.panelTargets.forEach((p) => {
      p.style.display = p.dataset.tab === this.activeValue ? "" : "none"
    })
    this.tabTargets.forEach((t) => {
      const on = t.dataset.tab === this.activeValue
      t.classList.toggle("text-zinc-100", on)
      t.classList.toggle("font-semibold", on)
      t.classList.toggle("text-zinc-400", !on)
      t.classList.toggle("font-medium", !on)
      if (on) {
        t.style.backgroundColor = "var(--studs-panel-bg-2)"
        t.style.boxShadow = "0 1px 3px rgba(0,0,0,0.3)"
      } else {
        t.style.removeProperty("background-color")
        t.style.removeProperty("box-shadow")
      }
    })
  }

  _syncVisibility() {
    if (!this.hasWidgetTarget) return
    const anyVisible = Array.from(document.querySelectorAll("[data-event-drag-target='day']"))
      .some((d) => { const r = d.getBoundingClientRect(); return r.width > 0 && r.height > 0 })
    this.widgetTarget.style.display = anyVisible ? "" : "none"
  }
}
