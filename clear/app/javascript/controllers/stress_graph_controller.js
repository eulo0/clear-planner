import { Controller } from "@hotwired/stimulus"

// Interactivity for the server-rendered stress SVG:
//  - hover tooltips on each non-peak data dot
//  - peak callout shown ONLY while hovering the peak dot (or the callout itself)
//  - the "Plan in draft" CTA is intentionally inert in v1
export default class extends Controller {
  static targets = ["dot", "peak", "tip", "callout", "cta"]

  connect() {
    this.dotTargets.forEach(dot => {
      dot.addEventListener("mouseenter", this._showTip.bind(this, dot))
      dot.addEventListener("mouseleave", this._hideTip.bind(this))
    })

    if (this.hasCtaTarget) {
      // inert in v1 — prevent any accidental form/navigation behavior
      this.ctaTarget.addEventListener("click", e => e.preventDefault())
    }

    // Peak callout is hover-only. Keep it open while the cursor is over the
    // peak dot OR the callout, so the card can be read/interacted with.
    if (this.hasPeakTarget && this.hasCalloutTarget) {
      this._show = () => { clearTimeout(this._hideTimer); this.placeCallout() }
      this._scheduleHide = () => { this._hideTimer = setTimeout(() => this._hideCallout(), 160) }
      this.peakTarget.addEventListener("mouseenter", this._show)
      this.peakTarget.addEventListener("mouseleave", this._scheduleHide)
      this.calloutTarget.addEventListener("mouseenter", () => clearTimeout(this._hideTimer))
      this.calloutTarget.addEventListener("mouseleave", this._scheduleHide)
    }

    this._onResize = () => {
      if (this.hasCalloutTarget && this.calloutTarget.style.display === "block") this.placeCallout()
    }
    window.addEventListener("resize", this._onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    clearTimeout(this._hideTimer)
  }

  get svg() { return this.element.querySelector("svg") }

  _toPx(vx, vy) {
    const r = this.svg.getBoundingClientRect()
    const cr = this.element.getBoundingClientRect()
    const scale = r.width / 720
    return { left: (r.left - cr.left) + vx * scale, top: (r.top - cr.top) + vy * scale }
  }

  _showTip(dot) {
    if (!this.hasTipTarget) return
    // The peak dot uses the rich callout instead of the small tooltip.
    if (this.hasPeakTarget && dot === this.peakTarget) return
    this.tipTarget.textContent = dot.getAttribute("data-label")
    const px = this._toPx(+dot.getAttribute("cx"), +dot.getAttribute("cy"))
    this.tipTarget.style.display = "block"
    this.tipTarget.style.left = px.left + "px"
    this.tipTarget.style.top = (px.top - 30) + "px"
  }

  _hideTip() {
    if (this.hasTipTarget) this.tipTarget.style.display = "none"
  }

  _hideCallout() {
    if (this.hasCalloutTarget) this.calloutTarget.style.display = "none"
  }

  placeCallout() {
    if (!this.hasCalloutTarget || !this.hasPeakTarget) return
    const r = this.svg.getBoundingClientRect()
    if (!r.width) return
    const dot = this.peakTarget
    const px = this._toPx(+dot.getAttribute("cx"), +dot.getAttribute("cy"))
    const cr = this.element.getBoundingClientRect()
    const co = this.calloutTarget
    co.style.display = "block"
    co.classList.remove("above", "below")
    const cw = co.offsetWidth, ch = co.offsetHeight, gap = 14
    let left = Math.max(6, Math.min(px.left - cw / 2, cr.width - cw - 6))
    co.style.left = left + "px"
    co.style.setProperty("--arrow-x", (px.left - left) + "px")
    if (px.top - ch - gap >= 0) {
      co.classList.add("above")
      co.style.top = (px.top - ch - gap) + "px"
    } else {
      co.classList.add("below")
      co.style.top = (px.top + gap) + "px"
    }
  }
}
