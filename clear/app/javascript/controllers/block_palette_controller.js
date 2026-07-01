import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Drag a routine-block TEMPLATE from the agenda panel onto the calendar to
// create a recurring availability block (dashed hatch band) on that weekday.
// Blocks are NOT part of the draft system: POST /blocks writes directly and the
// returned Turbo Stream re-renders the calendar frame. Mirrors
// task_palette_controller, but creates a block instead of scheduling a task.
//
// Day/week only: day columns carry [data-event-drag-target='day']; in month
// view they're zero-size (hidden), in year view absent — so drops + the palette
// visibility check no-op outside day/week.
export default class extends Controller {
  static targets = ["palette", "chip"]
  static values = {
    createUrl: String,
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

    this.label = chip.dataset.label
    this.color = chip.dataset.color
    this.durationMin = parseInt(chip.dataset.durationMinutes, 10) || 120

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
    if (!target) { this._cleanup(); return }
    this._submit(target)
  }

  _target(event) {
    const column = this._dayAt(event.clientX, event.clientY)
    if (!column) return null
    const colRect = column.getBoundingClientRect()
    let startMin = this._snap((event.clientY - colRect.top) / this.pxPerMinute)
    startMin = Math.max(0, Math.min(startMin, this.dayMinutes - this.durationMin))
    const endMin = startMin + this.durationMin
    const wday = parseInt(column.dataset.wday, 10)
    return { column, startMin, endMin, wday, date: column.dataset.date }
  }

  _submit({ startMin, endMin, wday, date }) {
    const body = new URLSearchParams()
    body.set("block[label]", this.label)
    body.set("block[color]", this.color)
    body.set("block[status]", "active")
    body.set("block[start_minute]", String(startMin))
    body.set("block[end_minute]", String(endMin))
    body.append("block[repeat_days][]", String(wday))
    if (date) body.set("start_date", date)
    const filter = new URLSearchParams(window.location.search).get("filter")
    if (filter) body.set("filter", filter)
    if (document.querySelector('[data-calendar-view-target="dayMarker"]')) body.set("view", "daily")

    this._cleanup()

    fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this._csrf(),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      credentials: "same-origin",
      body: body.toString(),
    })
      .then((r) => (r.ok ? r.text() : Promise.reject(r.status)))
      .then((html) => Turbo.renderStreamMessage(html))
      .catch(() => {})
  }

  _moveGhost(event) {
    this.ghost.style.left = `${event.clientX + 8}px`
    this.ghost.style.top = `${event.clientY + 8}px`
  }

  _dayAt(clientX, clientY) {
    const cols = Array.from(document.querySelectorAll("[data-event-drag-target='day']"))
    return cols.find((d) => {
      const r = d.getBoundingClientRect()
      if (r.width === 0 || r.height === 0) return false
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

  _csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
