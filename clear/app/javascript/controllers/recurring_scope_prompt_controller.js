import { Controller } from "@hotwired/stimulus"

// GCal-style "this / this & following / all" prompt for dragging a recurring
// event. Listens for the `event-drag:recurring` event dispatched by the
// event-drag controller, which carries { submit(scope), revert() } callbacks.
// The controller is mounted on the calendar root (so it catches the bubbling
// event); the dialog itself is the `overlay` target that we show/hide.
export default class extends Controller {
  static targets = ["overlay"]

  open(event) {
    this.pending = event.detail
    this.overlayTarget.classList.remove("hidden")
    this._onKeydown = (e) => { if (e.key === "Escape") this.cancel() }
    window.addEventListener("keydown", this._onKeydown)
  }

  choose(event) {
    const scope = event.currentTarget.dataset.scope
    const pending = this.pending
    this._hide()
    pending?.submit(scope)
  }

  cancel() {
    const pending = this.pending
    this._hide()
    pending?.revert()
  }

  _hide() {
    this.pending = null
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("hidden")
    window.removeEventListener("keydown", this._onKeydown)
  }
}
