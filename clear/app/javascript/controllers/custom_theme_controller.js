import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { snapshot: Object, profilePath: String }

  connect() {
    // Snapshot all current CSS variable values before user changes anything
    const vars = [
      "--studs-accent",
      "--studs-accent-secondary",
      "--studs-accent-text",
      "--studs-sidebar-bg",
      "--studs-panel-bg",
      "--studs-panel-bg-2",
      "--studs-panel-hover",
      "--studs-panel-header",
      "--studs-border",
      "--studs-border-subtle",
      "--studs-divider",
    ]

    const style = getComputedStyle(document.body)
    this.snapshot = {}
    vars.forEach(v => {
      this.snapshot[v] = style.getPropertyValue(v).trim()
    })

    // Set each color input's initial value from the current CSS variable
    this.element.querySelectorAll("[data-css-var]").forEach(input => {
      const current = style.getPropertyValue(input.dataset.cssVar).trim()
      // Convert to hex if possible for the color picker
      input.value = this.toHex(current) || "#000000"
    })
  }

  update(event) {
    const input = event.target
    document.body.style.setProperty(input.dataset.cssVar, input.value)
  }

  cancel() {
  Object.entries(this.snapshot).forEach(([key, value]) => {
    document.body.style.setProperty(key, value)
  })
  const frame = document.getElementById("profile_modal")
  if (frame) frame.src = this.profilePathValue
}

save() {
  const frame = document.getElementById("profile_modal")
  if (frame) frame.src = this.profilePathValue
}

  toHex(color) {
    if (!color) return null
    if (color.startsWith("#")) return color
    // For rgba values, extract the rgb part and convert
    const match = color.match(/[\d.]+/g)
    if (!match || match.length < 3) return null
    return "#" + [match[0], match[1], match[2]]
      .map(n => parseInt(n).toString(16).padStart(2, "0"))
      .join("")
  }
}