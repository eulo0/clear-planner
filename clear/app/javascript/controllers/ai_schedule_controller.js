import { Controller } from "@hotwired/stimulus"

const HOLLOW = { opacity: "0.4", pointerEvents: "none" }
const ACTIVE = { opacity: "1", pointerEvents: "auto" }

export default class extends Controller {
  connect() {
    this.currentPage = 0
    this.render()
  }

  prev() {
    if (this.currentPage === 0) return
    this.currentPage = 0
    this.render()
  }

  next() {
    if (this.currentPage === 1) return
    this.currentPage = 1
    this.render()
  }

  render() {
    this.element.querySelectorAll("[data-ai-schedule-page]").forEach((e, i) => {
      e.style.display = i === this.currentPage ? "" : "none"
    })
    this.element.querySelectorAll("[data-ai-schedule-week-label]").forEach((e, i) => {
      e.style.display = i === this.currentPage ? "" : "none"
    })
    const prev = this.element.querySelector("[data-ai-schedule-prev]")
    const next = this.element.querySelector("[data-ai-schedule-next]")
    if (prev) Object.assign(prev.style, this.currentPage === 0 ? HOLLOW : ACTIVE)
    if (next) Object.assign(next.style, this.currentPage === 1 ? HOLLOW : ACTIVE)
  }
}
