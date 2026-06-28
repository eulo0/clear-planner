import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "frame", "skeleton"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false

    this._onKeydown = (e) => {
      if (e.key === "Escape") this.close()
    }
    window.addEventListener("keydown", this._onKeydown)

    if (this.hasFrameTarget) {
      this._observer = new MutationObserver(() => this.syncWithFrame())
      this._observer.observe(this.frameTarget, {
        childList: true,
        characterData: true,
        subtree: true
      })
    }

    this.render()
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
    this._observer?.disconnect()
    window.clearTimeout(this._closeTimer)
  }

  start() {
    this._suppressSync = true

    window.clearTimeout(this._skeletonTimer)
    this._skeletonTimer = window.setTimeout(() => {
      const empty = this.hasFrameTarget && this.frameTarget.innerHTML.trim() === ""
      if (empty) this.showSkeleton()
    }, 120)

    queueMicrotask(() => { this._suppressSync = false })
  }
  open() {
    this.openValue = true
    this.render()
  }

  close(event) {
    event?.preventDefault()

    window.clearTimeout(this._closeTimer)

    this.openValue = false
    this.render()

    this.clearFrame()

    this._closeTimer = window.setTimeout(() => {
      if (!this.openValue) this.clearFrame()
    }, 320)
  }

  frameLoaded() {
    window.clearTimeout(this._skeletonTimer)
    if (this._skipNextFrameLoad) {
      this._skipNextFrameLoad = false
      return
    }
    this.open()
  }

  showSkeleton() {
    if (!this.hasSkeletonTarget || !this.hasFrameTarget) return
    this.frameTarget.innerHTML = this.skeletonTarget.innerHTML
  }

  submitEnded(event) {
    if (!event.detail?.success) {
      this.open()
      return
    }

    const form = event.detail.formSubmission?.formElement
    const shouldClose = form?.dataset?.drawerCloseOnSuccess === "true"
    if (shouldClose) {
      this._skipNextFrameLoad = true
      this.close()
    }
  }

  syncWithFrame() {
    if (!this.hasFrameTarget) return
    if (this._suppressSync) return

    const empty = this.frameTarget.innerHTML.trim() === ""
    if (empty && this.openValue) this.close()
    else if (!empty && !this.openValue) this.open()
  }

  clearFrame() {
    if (!this.hasFrameTarget) return
    this.frameTarget.innerHTML = ""
    this.frameTarget.removeAttribute("src")
  }

  render() {
    if (!this.hasOverlayTarget || !this.hasPanelTarget) return

    if (this.openValue) {
      this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.add("opacity-100")

      this.panelTarget.classList.remove("translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
    } else {
      this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
      this.overlayTarget.classList.remove("opacity-100")

      this.panelTarget.classList.add("translate-x-full")
      this.panelTarget.classList.remove("translate-x-0")
    }
  }
}
