import { Controller } from "@hotwired/stimulus"

// Small delete-only popover for availability blocks on the dashboard calendar.
// Opened by block_builder when a band is clicked (not dragged) via the
// `block-builder:requestMenu` event. Positioning mirrors event_popover.
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._onKeydown = (e) => { if (e.key === "Escape") this.close() }
    this._onClickOutside = (e) => {
      if (!this._open) return
      if (this.menuTarget.contains(e.target)) return
      // Ignore the trailing click on a band (the pointerup that opened this
      // popover is followed by a click event) and clicks that switch to
      // another band — those re-open via the requestMenu event instead.
      if (e.target.closest("[data-block-builder-target='band']")) return
      this.close()
    }
    window.addEventListener("keydown", this._onKeydown)
    document.addEventListener("click", this._onClickOutside, true)
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("click", this._onClickOutside, true)
  }

  open(event) {
    this.band = event.detail.band
    if (!this.band) return
    this._open = true
    this._position(this.band)
    this.menuTarget.classList.remove("hidden")
  }

  close() {
    this._open = false
    this.band = null
    this.menuTarget.classList.add("hidden")
  }

  delete(event) {
    event.preventDefault()
    const band = this.band
    const url  = band?.dataset.deleteUrl
    if (!url) { this.close(); return }

    fetch(url, {
      method: "DELETE",
      headers: { "Accept": "application/json", "X-CSRF-Token": this._csrf() },
      credentials: "same-origin",
    })
      .then((r) => { if (r.ok) band.remove() })
      .finally(() => this.close())
  }

  _position(anchor) {
    const menu = this.menuTarget
    const scrollParent = anchor.closest(".overflow-auto") || this.element

    menu.style.visibility = "hidden"
    menu.classList.remove("hidden")
    const menuHeight = menu.offsetHeight
    const menuWidth  = menu.offsetWidth || 180
    menu.style.visibility = ""

    const anchorRect = anchor.getBoundingClientRect()
    const scrollRect = scrollParent.getBoundingClientRect()

    // Prefer below the band; flip above if it would overflow the scroll area.
    let top = anchorRect.bottom - scrollRect.top + scrollParent.scrollTop + 6
    const visibleBottom = scrollParent.scrollTop + scrollParent.clientHeight
    if (top + menuHeight > visibleBottom) {
      top = anchorRect.top - scrollRect.top + scrollParent.scrollTop - menuHeight - 6
    }

    let left = anchorRect.left - scrollRect.left + scrollParent.scrollLeft
    if (left + menuWidth > scrollParent.clientWidth - 8) {
      left = scrollParent.clientWidth - menuWidth - 8
    }
    left = Math.max(8, left)

    menu.style.top  = `${top}px`
    menu.style.left = `${left}px`
  }

  _csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
