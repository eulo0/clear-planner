import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  cancel() {
    this.element.classList.add("hidden")
  }

  onSubmitEnd(event) {
    if (!event.detail.success) return

    this.element.classList.add("pointer-events-none")
    const card = this.element.querySelector("[data-ai-form-card]")
    if (!card) return
    const btn = card.querySelector(".studs-nav-btn")
    if (!btn) return
    btn.style.backgroundColor = "transparent"
    btn.style.boxShadow = "none"
    btn.style.opacity = "0.5"
  }
}
