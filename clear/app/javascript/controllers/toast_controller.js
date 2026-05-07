import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    // Slide in
    requestAnimationFrame(() => {
      this.element.classList.remove("translate-x-full", "opacity-0")
      this.element.classList.add("translate-x-0", "opacity-100")
    })

    // Start progress bar shrink.
    // Double rAF ensures the element is painted at width:100% before the
    // transition to 0% fires — required for dynamically injected toasts.
    const bar = this.element.querySelector("[data-toast-progress]")
    if (bar) {
      requestAnimationFrame(() => {
        bar.style.transition = `width ${this.durationValue}ms linear`
        requestAnimationFrame(() => {
          bar.style.width = "0%"
        })
      })
    }

    // Auto-dismiss
    this.timer = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  dismiss() {
    if (this.timer) clearTimeout(this.timer)

    this.element.classList.remove("translate-x-0", "opacity-100")
    this.element.classList.add("translate-x-full", "opacity-0")

    this.element.addEventListener("transitionend", () => {
      this.element.remove()
    }, { once: true })

    // Fallback removal if transitionend doesn't fire
    setTimeout(() => {
      if (this.element.parentNode) this.element.remove()
    }, 400)
  }
}
