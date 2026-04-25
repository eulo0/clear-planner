import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { snapshot: Object, profilePath: String }

  connect() {
  const style = getComputedStyle(document.body)
  this.snapshot = {}
  const vars = [
    "--studs-accent", "--studs-accent-secondary", "--studs-accent-text",
    "--studs-sidebar-bg", "--studs-panel-bg", "--studs-panel-bg-2",
    "--studs-panel-hover", "--studs-panel-header", "--studs-border",
    "--studs-border-subtle", "--studs-divider"
  ]

  // Snapshot current theme first so cancel can restore it
  vars.forEach(v => {
    this.snapshot[v] = style.getPropertyValue(v).trim()
  })

  // Apply the edited theme's values to the page immediately
  this.element.querySelectorAll("[data-css-var]").forEach(input => {
    if (input.value && input.value !== "#000000") {
      document.body.style.setProperty(input.dataset.cssVar, input.value)
    }
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