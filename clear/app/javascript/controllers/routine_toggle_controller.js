import { Controller } from "@hotwired/stimulus"

// Shows/hides the availability-routine bands on the calendar. Routines are a
// background layer, so they default to hidden and this toggle opts them in.
// State is purely client-side (no server round-trip — the bands are already in
// the DOM) and persisted in localStorage so it survives calendar navigation.
export default class extends Controller {
  static targets = ["button"]

  static STORAGE_KEY = "clear:routinesVisible"

  connect() {
    this.visible = window.localStorage.getItem(this.constructor.STORAGE_KEY) === "true"
    this.render()
  }

  toggle() {
    this.visible = !this.visible
    try {
      window.localStorage.setItem(this.constructor.STORAGE_KEY, String(this.visible))
    } catch (_e) {
      // localStorage may be unavailable (private mode); toggle still works for the session.
    }
    this.render()
  }

  render() {
    this.element.classList.toggle("routines-visible", this.visible)
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", String(this.visible))
    }
  }
}
