import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Drag an unscheduled task from the agenda panel onto the calendar grid.
// On drop we PATCH tasks#reschedule (which sets scheduled_at + duration and is
// draft-aware) and let the returned Turbo Stream re-render the calendar frame.
// Reuses the same drop math as event_drag_controller.
//
// "Day & week only" falls out for free: day columns carry
// [data-event-drag-target='day']. In month view they're inside a hidden wrapper
// (zero-size rect); in year view they don't exist. So both the palette
// visibility check and the drop hit-test naturally no-op outside day/week.
export default class extends Controller {
  static targets = ["palette", "chip"]
  static values = {
    hourHeight: { type: Number, default: 72 },
    snapMinutes: { type: Number, default: 15 },
  }

  connect() {
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
    this._cleanup()
  }

  get pxPerMinute() { return this.hourHeightValue / 60.0 }
  get dayMinutes() { return 24 * 60 }

  startDrag(event) {
    if (event.button !== undefined && event.button !== 0) return
    const chip = event.currentTarget
    event.preventDefault()

    this.chip = chip
    this.durationMin = parseInt(chip.dataset.durationMinutes, 10) || 60
    this.rescheduleUrl = chip.dataset.rescheduleUrl

    // Floating ghost that follows the cursor.
    this.ghost = chip.cloneNode(true)
    this.ghost.style.position = "fixed"
    this.ghost.style.zIndex = "200"
    this.ghost.style.width = `${chip.offsetWidth}px`
    this.ghost.style.pointerEvents = "none"
    this.ghost.style.opacity = "0.9"
    document.body.appendChild(this.ghost)
    this._moveGhost(event)

    this._onMove = this._pointerMove.bind(this)
    this._onUp = this._pointerUp.bind(this)
    window.addEventListener("pointermove", this._onMove)
    window.addEventListener("pointerup", this._onUp, { once: true })
  }

  _pointerMove(event) {
    if (!this.ghost) return
    this._moveGhost(event)
    this._highlight(this._target(event)?.column || null)
  }

  _pointerUp(event) {
    window.removeEventListener("pointermove", this._onMove)
    const target = this._target(event)
    if (!target) { this._cleanup(); return } // dropped off-grid → cancel
    const start = this._dateAtMinutes(target.column.dataset.date, target.minutes)
    const end = new Date(start.getTime() + this.durationMin * 60000)
    this._submit(target.column.dataset.date, start, end)
  }

  _target(event) {
    const column = this._dayAt(event.clientX, event.clientY)
    if (!column) return null
    const colRect = column.getBoundingClientRect()
    let minutes = this._snap((event.clientY - colRect.top) / this.pxPerMinute)
    minutes = Math.max(0, Math.min(minutes, this.dayMinutes - this.durationMin))
    return { column, minutes }
  }

  _submit(startDate, start, end) {
    const chip = this.chip
    const url = this.rescheduleUrl
    const body = new URLSearchParams()
    body.set("start_date", startDate)
    body.set("new_starts_at", this._iso(start))
    body.set("new_ends_at", this._iso(end))
    const filter = new URLSearchParams(window.location.search).get("filter")
    if (filter) body.set("filter", filter)
    if (document.querySelector('[data-calendar-view-target="dayMarker"]')) body.set("view", "daily")

    this._cleanup()

    fetch(url, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this._csrf(),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      credentials: "same-origin",
      body: body.toString(),
    })
      .then((r) => (r.ok ? r.text() : Promise.reject(r.status)))
      .then((html) => {
        Turbo.renderStreamMessage(html)
        chip?.remove() // task is now scheduled → drop it from the palette
      })
      .catch(() => {})
  }

  // --- helpers ---

  _moveGhost(event) {
    this.ghost.style.left = `${event.clientX + 8}px`
    this.ghost.style.top = `${event.clientY + 8}px`
  }

  _dayAt(clientX, clientY) {
    const cols = Array.from(document.querySelectorAll("[data-event-drag-target='day']"))
    return cols.find((d) => {
      const r = d.getBoundingClientRect()
      if (r.width === 0 || r.height === 0) return false // hidden (month/year)
      return clientX >= r.left && clientX <= r.right && clientY >= r.top && clientY <= r.bottom
    })
  }

  _highlight(column) {
    if (this._hl && this._hl !== column) this._hl.style.removeProperty("box-shadow")
    if (column) column.style.boxShadow = "inset 0 0 0 2px var(--studs-accent)"
    this._hl = column
  }

  _syncVisibility() {
    if (!this.hasPaletteTarget) return
    const anyVisible = Array.from(document.querySelectorAll("[data-event-drag-target='day']"))
      .some((d) => { const r = d.getBoundingClientRect(); return r.width > 0 && r.height > 0 })
    this.paletteTarget.style.display = anyVisible ? "" : "none"
  }

  _cleanup() {
    this.ghost?.remove()
    this.ghost = null
    this._highlight(null)
    if (this._onMove) window.removeEventListener("pointermove", this._onMove)
  }

  _snap(m) { const s = this.snapMinutesValue; return Math.round(m / s) * s }

  _dateAtMinutes(isoDate, minutes) {
    const [y, m, d] = isoDate.split("-").map(Number)
    return new Date(y, m - 1, d, Math.floor(minutes / 60), minutes % 60, 0, 0)
  }

  _iso(date) {
    const p = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}T${p(date.getHours())}:${p(date.getMinutes())}:00`
  }

  _csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
