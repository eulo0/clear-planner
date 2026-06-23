import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Drag-to-move and bottom-edge resize for timed events in the weekly view.
// Phase 1: live calendar only. Disabled when draftValue is true.
// The server (EventsController#reschedule) is authoritative — on drop we PATCH
// and let the returned Turbo Stream re-render the calendar frame (which also
// recomputes overlap columns), so we only need lightweight optimistic feedback.
export default class extends Controller {
  static targets = ["day", "event"]
  static values = {
    hourHeight: { type: Number, default: 72 },
    snapMinutes: { type: Number, default: 30 },
  }

  get pxPerMinute() {
    return this.hourHeightValue / 60.0
  }

  get dayMinutes() {
    return 24 * 60
  }

  startMove(event) {
    this._begin(event, "move")
  }

  startResize(event) {
    // The handle lives inside the event <a>; don't also start a move.
    event.stopPropagation()
    this._begin(event, "resize")
  }

  _begin(event, mode) {
    if (event.button !== undefined && event.button !== 0) return

    const el = event.currentTarget.closest("[data-event-drag-target='event']")
    if (!el) return

    event.preventDefault()

    this.mode = mode
    this.dragEl = el
    this.moved = false
    this.startX = event.clientX
    this.startY = event.clientY

    this.grabOffsetY = event.clientY - el.getBoundingClientRect().top
    // Captured before any transform: the block's own rect and its day column's
    // rect. All snapped positions are expressed relative to these.
    this.originRect = el.getBoundingClientRect()
    this.originColumn = el.closest("[data-event-drag-target='day']")
    this.originColRect = this.originColumn?.getBoundingClientRect()
    this.lastTarget = null

    this.startAt = new Date(el.dataset.eventStart)
    this.endAt = new Date(el.dataset.eventEnd)
    this.durationMs = this.endAt - this.startAt
    this.startMinutes = this.startAt.getHours() * 60 + this.startAt.getMinutes()

    this._onMove = this._pointerMove.bind(this)
    this._onUp = this._pointerUp.bind(this)
    window.addEventListener("pointermove", this._onMove)
    window.addEventListener("pointerup", this._onUp, { once: true })

    el.style.zIndex = "60"
    el.style.transition = "none"
  }

  _pointerMove(event) {
    if (!this.dragEl) return
    const dx = event.clientX - this.startX
    const dy = event.clientY - this.startY
    if (!this.moved && Math.hypot(dx, dy) > 3) this.moved = true
    if (!this.moved) return

    // Snap live, GCal-style: compute the grid-aligned target and render the
    // block there in discrete 30-min / per-column steps (no free-floating).
    const target = this.mode === "move" ? this._moveTarget(event) : this._resizeTarget(event)
    if (!target) return
    this.lastTarget = target
    if (this.mode === "move") this._renderMove(this.dragEl, target)
    else this._renderResize(this.dragEl, target)
  }

  _pointerUp(event) {
    window.removeEventListener("pointermove", this._onMove)
    const el = this.dragEl
    this.dragEl = null
    if (!el) return

    if (!this.moved) {
      // A plain click — restore styles and let popover/navigation happen.
      this._resetEl(el)
      return
    }

    // Suppress the click that follows this drag so the link doesn't navigate.
    this._suppressNextClick(el)

    // The block is already sitting at the snapped target from the last move;
    // submit that exact position so there's no settle on the server re-render.
    const target = this.lastTarget || (this.mode === "move" ? this._moveTarget(event) : this._resizeTarget(event))
    if (!target) {
      this._resetEl(el)
      return
    }

    let newStart, newEnd
    if (this.mode === "move") {
      newStart = this._dateAtMinutes(target.column.dataset.date, target.minutes)
      newEnd = new Date(newStart.getTime() + this.durationMs)
    } else {
      newStart = this.startAt
      newEnd = this._dateAtMinutes(el.dataset.occurrenceDate, target.endMinutes)
    }

    this.submit(el, newStart, newEnd)
  }

  // Snapped move target: which day column + start-minutes the block lands on.
  _moveTarget(event) {
    const column = this._dayAt(event.clientX) || this.originColumn
    if (!column) return null
    const colRect = column.getBoundingClientRect()
    const topPx = event.clientY - colRect.top - this.grabOffsetY
    let minutes = this._snap(topPx / this.pxPerMinute)
    const durationMin = Math.round(this.durationMs / 60000)
    minutes = Math.max(0, Math.min(minutes, this.dayMinutes - durationMin))
    return { column, minutes }
  }

  // Snapped resize target: end-minutes on the same day (start is fixed).
  _resizeTarget(event) {
    const column = this.originColumn
    if (!column) return null
    const colRect = column.getBoundingClientRect()
    let endMinutes = this._snap((event.clientY - colRect.top) / this.pxPerMinute)
    endMinutes = Math.max(this.startMinutes + this.snapMinutesValue, Math.min(endMinutes, this.dayMinutes))
    return { column, endMinutes }
  }

  _renderMove(el, { column, minutes }) {
    const colRect = column.getBoundingClientRect()
    // Shift by the column delta (preserves the block's inset/width) and place
    // its top on the snapped grid line.
    const dx = colRect.left - this.originColRect.left
    const dy = (colRect.top + minutes * this.pxPerMinute) - this.originRect.top
    el.style.transform = `translate(${dx}px, ${dy}px)`
    el.style.opacity = "0.9"
  }

  _renderResize(el, { endMinutes }) {
    el.style.height = `${(endMinutes - this.startMinutes) * this.pxPerMinute}px`
    el.style.opacity = "0.9"
  }

  // Recurring events need a scope choice (this / following / all). Step 7 wires
  // the prompt; until then a recurring drag asks via the modal dispatch, and a
  // non-recurring drag submits immediately.
  submit(el, newStart, newEnd, scope = null) {
    if (el.dataset.eventRecurring === "true" && scope === null) {
      this.dispatch("recurring", {
        detail: {
          submit: (chosenScope) => this.submit(el, newStart, newEnd, chosenScope),
          revert: () => this._resetEl(el),
        },
      })
      return
    }

    const body = new URLSearchParams()
    body.set("start_date", el.dataset.occurrenceDate)
    // Stable origin date so re-dragging a relocated occurrence updates the same
    // override row instead of duplicating it (see EventsController#reschedule).
    body.set("anchor_date", el.dataset.anchorDate || el.dataset.occurrenceDate)
    body.set("new_starts_at", this._iso(newStart))
    body.set("new_ends_at", this._iso(newEnd))
    if (scope) body.set("scope", scope)
    const filter = new URLSearchParams(window.location.search).get("filter")
    if (filter) body.set("filter", filter)

    fetch(el.dataset.rescheduleUrl, {
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
      .then((html) => Turbo.renderStreamMessage(html))
      .catch(() => this._resetEl(el))
  }

  // --- helpers ---

  _dayAt(clientX) {
    return this.dayTargets.find((d) => {
      const r = d.getBoundingClientRect()
      return clientX >= r.left && clientX <= r.right
    })
  }

  _snap(minutes) {
    const s = this.snapMinutesValue
    return Math.round(minutes / s) * s
  }

  _dateAtMinutes(isoDate, minutes) {
    const [y, m, d] = isoDate.split("-").map(Number)
    return new Date(y, m - 1, d, Math.floor(minutes / 60), minutes % 60, 0, 0)
  }

  _iso(date) {
    // Local wall-clock ISO without timezone suffix; server parses in app zone.
    const p = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}T${p(date.getHours())}:${p(date.getMinutes())}:00`
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

  // Restore an element to its server-rendered state (used on click, cancel, or
  // a failed PATCH). The server remains the source of truth for the final slot.
  _resetEl(el) {
    if (!el) return
    el.style.transform = ""
    el.style.opacity = ""
    el.style.zIndex = ""
    el.style.transition = ""
  }
}
