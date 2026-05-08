import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { snapshot: Object, profilePath: String }
  static targets = ["errors", "errorList"]

  connect() {
    const style = getComputedStyle(document.body)
    this.snapshot = {}
    const vars = [
      "--studs-accent", "--studs-accent-secondary", "--studs-accent-text",
      "--studs-sidebar-bg", "--studs-panel-bg", "--studs-panel-bg-2",
      "--studs-panel-hover", "--studs-panel-header", "--studs-border",
      "--studs-border-subtle", "--studs-divider", "--studs-body-bg", "--studs-text"
    ]

    const overlay = document.querySelector("[data-modal-target='overlay']")
    if (overlay) {
      this.modalOverlay = overlay
      this.snapshotOverlay = overlay.className
      overlay.classList.remove("backdrop-blur-sm")
    }

    vars.forEach(v => {
      this.snapshot[v] = style.getPropertyValue(v).trim()
    })

    // Snapshot and freeze body background
    this.snapshotBackground = document.body.getAttribute("style") || ""
    const computedBg = getComputedStyle(document.body).background
    document.body.style.setProperty("background", computedBg, "important")

    // Snapshot and freeze topbar background
    const topbar = document.querySelector(".studs-topbar")
    if (topbar) {
      this.snapshotTopbar = topbar.getAttribute("style") || ""
      const computedTopbarBg = getComputedStyle(topbar).backgroundColor
      topbar.style.setProperty("background-color", computedTopbarBg, "important")
    }

    // Apply edited theme values to page immediately
    this.element.querySelectorAll("[data-css-var]").forEach(input => {
      if (input.value && input.value !== "#000000") {
        document.body.style.setProperty(input.dataset.cssVar, input.value)
      }
    })
  }

  update(event) {
    const input = event.target
    document.body.style.setProperty(input.dataset.cssVar, input.value)

    // Directly override background property for body bg changes
    if (input.dataset.cssVar === "--studs-body-bg") {
      document.body.style.setProperty("background", input.value, "important")
    }

    // Directly override topbar background for sidebar bg changes
    if (input.dataset.cssVar === "--studs-sidebar-bg") {
      const topbar = document.querySelector(".studs-topbar")
      if (topbar) topbar.style.setProperty("background-color", input.value, "important")
    }
  }

  cancel() {
    // Restore all snapshotted CSS variables
    Object.entries(this.snapshot).forEach(([key, value]) => {
      document.body.style.setProperty(key, value)
    })

    // Restore body background
    document.body.setAttribute("style", this.snapshotBackground)

    // Restore topbar background
    const topbar = document.querySelector(".studs-topbar")
    if (topbar) topbar.setAttribute("style", this.snapshotTopbar)

    const frame = document.getElementById("profile_modal")
    if (frame) frame.src = this.profilePathValue

    if (this.modalOverlay) {
      this.modalOverlay.className = this.snapshotOverlay
    }
  }

  save() {
    const frame = document.getElementById("profile_modal")
    if (frame) frame.src = this.profilePathValue
  }

  reset() {
    // Restore body background — the page reload will apply the new theme from DB
    document.body.setAttribute("style", this.snapshotBackground)

    // Restore topbar
    const topbar = document.querySelector(".studs-topbar")
    if (topbar) topbar.setAttribute("style", this.snapshotTopbar)

    if (this.modalOverlay) {
      this.modalOverlay.className = this.snapshotOverlay
    }
  }

  validate(event) {
    const errors = []
    const name = this.element.querySelector("[name='custom_theme[name]']").value.trim()

    if (!name) errors.push("Theme name can't be blank.")

    if (errors.length > 0) {
      event.preventDefault()
      this.errorListTarget.innerHTML = errors.map(e => `<li>${e}</li>`).join("")
      this.errorsTarget.classList.remove("hidden")
    } else {
      this.errorsTarget.classList.add("hidden")
    }
  }

  toHex(color) {
    if (!color) return null
    if (color.startsWith("#")) return color
    const match = color.match(/[\d.]+/g)
    if (!match || match.length < 3) return null
    return "#" + [match[0], match[1], match[2]]
      .map(n => parseInt(n).toString(16).padStart(2, "0"))
      .join("")
  }
}