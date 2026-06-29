import { Controller } from "@hotwired/stimulus"

// Drag-to-move and bottom-edge resize for routine block bands.
// Works in minute-space (start_minute / end_minute from midnight) unlike
// event_drag_controller which uses ISO timestamps. Mirrors the same
// pointer-event / snap / fetch(PATCH) / head(:ok) contract.
export default class extends Controller {
  static targets = ["band", "resizeHandle"]
  static values = {
    pxPerMinute:  { type: Number, default: 1.2 },
    gridStartMin: { type: Number, default: 360 },
    snapMinutes:  { type: Number, default: 15 },
  }

  // ── Entry points wired from each band's data-action attributes ──────────

  startMove(event) {
    if (event.button !== 0) return
    const band = event.currentTarget.closest("[data-block-builder-target='band']")
    if (!band) return
    event.preventDefault()
    this._begin(event, band, "move")
  }

  startResize(event) {
    event.stopPropagation()
    if (event.button !== 0) return
    const band = event.currentTarget.closest("[data-block-builder-target='band']")
    if (!band) return
    event.preventDefault()
    this._begin(event, band, "resize")
  }

  // ── Internal drag lifecycle ─────────────────────────────────────────────

  _begin(event, band, mode) {
    this.mode    = mode
    this.dragEl  = band
    this.moved   = false
    this.startY  = event.clientY

    this.originRect     = band.getBoundingClientRect()
    this.originalHeight = band.style.height
    this.grabOffsetY    = event.clientY - this.originRect.top
    this.startMinute    = parseInt(band.dataset.startMinute, 10)
    this.endMinute      = parseInt(band.dataset.endMinute, 10)
    this.durationMin    = this.endMinute - this.startMinute
    this.lastTarget     = null
    // Cache the column elements once so pointermove doesn't re-query the DOM.
    this._cols          = Array.from(this.element.querySelectorAll("[data-wday]"))

    this._onMove = this._pointerMove.bind(this)
    this._onUp   = this._pointerUp.bind(this)
    window.addEventListener("pointermove", this._onMove)
    window.addEventListener("pointerup",   this._onUp, { once: true })

    band.style.zIndex     = "60"
    band.style.transition = "none"
    band.style.opacity    = "0.85"
    band.style.cursor     = "grabbing"
  }

  _pointerMove(event) {
    if (!this.dragEl) return
    const dy = event.clientY - this.startY
    if (!this.moved && Math.abs(dy) > 3) this.moved = true
    if (!this.moved) return

    const colEl = this._colAt(event.clientX)
    if (!colEl) return

    if (this.mode === "move") {
      const colRect      = colEl.getBoundingClientRect()
      const rawTopInCol  = event.clientY - colRect.top - this.grabOffsetY
      const rawMinutes   = rawTopInCol / this.pxPerMinuteValue
      const snapped      = this._snap(this.gridStartMinValue + rawMinutes)
      const clamped      = Math.max(0, Math.min(snapped, 1440 - this.durationMin))
      this.lastTarget    = { startMinute: clamped, endMinute: clamped + this.durationMin, colEl }
      this._renderMove(this.dragEl, this.lastTarget)
    } else {
      // resize: fix start, move end
      const colRect     = this.dragEl.closest("[data-wday]").getBoundingClientRect()
      const rawTopInCol = event.clientY - colRect.top
      const rawMinutes  = rawTopInCol / this.pxPerMinuteValue
      const snappedEnd  = this._snap(this.gridStartMinValue + rawMinutes)
      const clampedEnd  = Math.max(this.startMinute + this.snapMinutesValue, Math.min(snappedEnd, 1440))
      this.lastTarget   = { startMinute: this.startMinute, endMinute: clampedEnd, colEl: this.dragEl.closest("[data-wday]") }
      this._renderResize(this.dragEl, clampedEnd)
    }
  }

  _pointerUp(event) {
    window.removeEventListener("pointermove", this._onMove)
    const el = this.dragEl
    this.dragEl = null
    if (!el) return

    if (!this.moved) {
      this._resetEl(el)
      return
    }

    this._suppressNextClick(el)

    const target = this.lastTarget
    if (!target) { this._resetEl(el); return }

    const newWday = parseInt(target.colEl.dataset.wday, 10)
    this._submit(el, target.startMinute, target.endMinute, newWday)
  }

  // ── Rendering helpers ───────────────────────────────────────────────────

  _renderMove(el, { startMinute, colEl }) {
    const colRect  = colEl.getBoundingClientRect()
    const origRect = this.originRect
    const dx = colRect.left - origRect.left
    const dy = (startMinute - this.startMinute) * this.pxPerMinuteValue
    el.style.transform = `translate(${dx}px, ${dy}px)`
  }

  _renderResize(el, endMinute) {
    const newHeight = (endMinute - this.startMinute) * this.pxPerMinuteValue
    el.style.height = `${Math.max(newHeight, 16)}px`
  }

  // ── Network ─────────────────────────────────────────────────────────────

  _submit(el, startMinute, endMinute, wday) {
    const url  = el.dataset.rescheduleUrl
    const body = new URLSearchParams()
    body.set("start_minute", startMinute)
    body.set("end_minute",   endMinute)
    // Persist day change: re-send repeat_days with the new wday replacing old ones.
    // For a simple move-within-day case, repeat_days may be unchanged but we
    // always send the value so the server can do partial day remap if needed.
    // Current implementation: the band carries its day implicitly (column). We
    // only update start/end_minute here; day changes would require a separate
    // update action (out of scope for v1 drag).
    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": this._csrf(),
      },
      credentials: "same-origin",
      body: body.toString(),
    })
      .then((r) => {
        if (r.ok) {
          // Commit the new position, then sync originalHeight so the
          // _resetEl height restore below is a no-op (not a revert).
          el.dataset.startMinute = startMinute
          el.dataset.endMinute   = endMinute
          el.style.top    = `${(startMinute - this.gridStartMinValue) * this.pxPerMinuteValue}px`
          const newHeight = `${Math.max((endMinute - startMinute) * this.pxPerMinuteValue, 16)}px`
          el.style.height = newHeight
          this.originalHeight = newHeight
          this._resetEl(el)
        } else {
          this._resetEl(el)
        }
      })
      .catch(() => this._resetEl(el))
  }

  // ── Utilities ────────────────────────────────────────────────────────────

  _colAt(clientX) {
    const cols = this._cols || []
    return cols.find((col) => {
      const r = col.getBoundingClientRect()
      return clientX >= r.left && clientX <= r.right
    }) || null
  }

  _snap(minutes) {
    const s = this.snapMinutesValue
    return Math.round(minutes / s) * s
  }

  _csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  _suppressNextClick(el) {
    const handler = (e) => {
      e.preventDefault()
      e.stopPropagation()
      el.removeEventListener("click", handler, true)
    }
    el.addEventListener("click", handler, true)
    setTimeout(() => el.removeEventListener("click", handler, true), 400)
  }

  _resetEl(el) {
    if (!el) return
    el.style.transform  = ""
    el.style.height     = this.originalHeight ?? ""
    el.style.opacity    = ""
    el.style.zIndex     = ""
    el.style.transition = ""
    el.style.cursor     = "grab"
  }
}
