import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video"]

  connect() {
    this.index = 0
    this.videoTargets.forEach((v, i) => {
      v.style.transition = "opacity 0.8s ease"
      v.style.opacity = i === 0 ? 1 : 0
      v.addEventListener("ended", () => this.advance())
    })
    this.videoTargets[0].play().catch(() => {})
  }

  advance() {
    const current = this.videoTargets[this.index]
    this.index = (this.index + 1) % this.videoTargets.length
    const next = this.videoTargets[this.index]

    next.currentTime = 0
    next.play().catch(() => {})

    next.style.opacity = 1
    current.style.opacity = 0
  }
}
